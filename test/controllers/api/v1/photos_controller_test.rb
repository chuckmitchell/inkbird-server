require "test_helper"
require "base64"

module Api
  module V1
    class PhotosControllerTest < ActionDispatch::IntegrationTest
      VALID_TOKEN = "test-secret-ingest-token-12345"
      SAMPLE_JPEG_BYTES = "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xFF\xD9".b.freeze

      setup do
        @original_token = ENV["INGEST_BEARER_TOKEN"]
        ENV["INGEST_BEARER_TOKEN"] = VALID_TOKEN

        @valid_payload = {
          device_id: "02720007bcddc234ce20",
          timestamp_utc: "2026-10-29T16:15:00Z",
          lens: "REAR_WIDE",
          width: 1280,
          height: 960,
          current_temp_c: 29.0,
          image_base64: Base64.strict_encode64(SAMPLE_JPEG_BYTES)
        }
      end

      teardown do
        ENV["INGEST_BEARER_TOKEN"] = @original_token
        FileUtils.rm_rf(DevicePhoto.storage_root)
      end

      test "returns 401 unauthorized when bearer token is missing or invalid" do
        post api_v1_photos_url, params: @valid_payload, as: :json
        assert_response :unauthorized

        post api_v1_photos_url,
          params: @valid_payload,
          headers: { "Authorization" => "Bearer wrong-token" },
          as: :json
        assert_response :unauthorized
      end

      test "returns 500 when INGEST_BEARER_TOKEN is not configured" do
        ENV["INGEST_BEARER_TOKEN"] = ""

        post api_v1_photos_url,
          params: @valid_payload,
          headers: { "Authorization" => "Bearer #{VALID_TOKEN}" },
          as: :json
        assert_response :internal_server_error
      end

      test "creates device and photo on valid payload and handles retries idempotently" do
        assert_difference [ "Device.count", "DevicePhoto.count" ], 1 do
          post api_v1_photos_url,
            params: @valid_payload,
            headers: { "Authorization" => "Bearer #{VALID_TOKEN}" },
            as: :json
        end

        assert_response :created
        body = JSON.parse(response.body)
        assert_equal "ok", body["status"]
        assert_not_nil body["photo_id"]

        photo = DevicePhoto.find(body["photo_id"])
        assert_equal "REAR_WIDE", photo.lens
        assert_equal 1280, photo.width
        assert_equal 960, photo.height
        assert_in_delta 29.0, photo.current_temp_c, 0.01
        assert_equal SAMPLE_JPEG_BYTES.bytesize, photo.byte_size
        assert photo.file_exists?
        assert_equal SAMPLE_JPEG_BYTES, File.binread(photo.absolute_file_path)

        device = Device.find_by!(tuya_device_id: "02720007bcddc234ce20")
        assert_equal Time.utc(2026, 10, 29, 16, 15, 0), device.last_seen_at

        # Retry identical submission
        assert_no_difference [ "Device.count", "DevicePhoto.count" ] do
          post api_v1_photos_url,
            params: @valid_payload,
            headers: { "Authorization" => "Bearer #{VALID_TOKEN}" },
            as: :json
        end

        assert_response :ok
        retry_body = JSON.parse(response.body)
        assert_equal photo.id, retry_body["photo_id"]
      end

      test "returns 422 when required fields are missing or image_base64 is not a valid JPEG" do
        post api_v1_photos_url,
          params: @valid_payload.except(:device_id),
          headers: { "Authorization" => "Bearer #{VALID_TOKEN}" },
          as: :json
        assert_response :unprocessable_entity

        post api_v1_photos_url,
          params: @valid_payload.merge(timestamp_utc: "invalid-date"),
          headers: { "Authorization" => "Bearer #{VALID_TOKEN}" },
          as: :json
        assert_response :unprocessable_entity

        post api_v1_photos_url,
          params: @valid_payload.merge(image_base64: Base64.strict_encode64("not a jpeg")),
          headers: { "Authorization" => "Bearer #{VALID_TOKEN}" },
          as: :json
        assert_response :unprocessable_entity
      end
    end
  end
end
