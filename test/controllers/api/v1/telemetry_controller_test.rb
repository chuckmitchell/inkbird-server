require "test_helper"

module Api
  module V1
    class TelemetryControllerTest < ActionDispatch::IntegrationTest
      VALID_TOKEN = "test-secret-ingest-token-12345"

      setup do
        @original_token = ENV["INGEST_BEARER_TOKEN"]
        ENV["INGEST_BEARER_TOKEN"] = VALID_TOKEN

        @valid_payload = {
          device_id: "02720007bcddc234ce20",
          timestamp_utc: "2026-10-29T16:15:00Z",
          unit: "C",
          current_temp_c: 29.0,
          current_temp_f: 84.2,
          target_temp_c: 8.0,
          relay_state: "cooling",
          compressor_delay_min: 3,
          high_alarm_limit: 35.0,
          low_alarm_limit: 0.0,
          alarms: {
            "111" => false,
            "112" => false,
            "113" => false
          },
          raw_dps: {
            "101" => "C",
            "104" => 290,
            "106" => 80,
            "108" => 3,
            "109" => 350,
            "110" => 0,
            "111" => false,
            "112" => false,
            "113" => false,
            "115" => "1",
            "116" => 842
          }
        }
      end

      teardown do
        ENV["INGEST_BEARER_TOKEN"] = @original_token
      end

      test "returns 401 unauthorized when bearer token is missing or invalid" do
        post api_v1_telemetry_url, params: @valid_payload, as: :json
        assert_response :unauthorized

        post api_v1_telemetry_url,
          params: @valid_payload,
          headers: { "Authorization" => "Bearer wrong-token" },
          as: :json
        assert_response :unauthorized
      end

      test "returns 500 when INGEST_BEARER_TOKEN is not configured" do
        ENV["INGEST_BEARER_TOKEN"] = ""

        post api_v1_telemetry_url,
          params: @valid_payload,
          headers: { "Authorization" => "Bearer #{VALID_TOKEN}" },
          as: :json
        assert_response :internal_server_error
      end

      test "creates device and telemetry reading on valid payload and handles retries idempotently" do
        assert_difference [ "Device.count", "TelemetryReading.count" ], 1 do
          post api_v1_telemetry_url,
            params: @valid_payload,
            headers: { "Authorization" => "Bearer #{VALID_TOKEN}" },
            as: :json
        end

        assert_response :created
        body = JSON.parse(response.body)
        assert_equal "ok", body["status"]
        assert_not_nil body["reading_id"]

        device = Device.find_by!(tuya_device_id: "02720007bcddc234ce20")
        assert_in_delta 29.0, device.last_temp_c, 0.01
        assert_in_delta 84.2, device.last_temp_f, 0.01
        assert_equal "cooling", device.last_relay_state
        assert_equal Time.utc(2026, 10, 29, 16, 15, 0), device.last_seen_at

        reading = TelemetryReading.find(body["reading_id"])
        assert_in_delta 8.0, reading.target_temp_c, 0.01
        assert_equal 3, reading.compressor_delay_min
        assert_equal false, reading.alarms["111"]
        assert_equal 290, reading.raw_dps["104"]

        # Retry identical submission (Android client retry behavior)
        assert_no_difference [ "Device.count", "TelemetryReading.count" ] do
          post api_v1_telemetry_url,
            params: @valid_payload,
            headers: { "Authorization" => "Bearer #{VALID_TOKEN}" },
            as: :json
        end

        assert_response :ok
        retry_body = JSON.parse(response.body)
        assert_equal reading.id, retry_body["reading_id"]
      end

      test "returns 422 when required fields are missing or invalid" do
        post api_v1_telemetry_url,
          params: @valid_payload.except(:device_id),
          headers: { "Authorization" => "Bearer #{VALID_TOKEN}" },
          as: :json
        assert_response :unprocessable_entity

        post api_v1_telemetry_url,
          params: @valid_payload.merge(timestamp_utc: "not-a-timestamp"),
          headers: { "Authorization" => "Bearer #{VALID_TOKEN}" },
          as: :json
        assert_response :unprocessable_entity

        post api_v1_telemetry_url,
          params: @valid_payload.merge(next_poll_utc: "invalid-iso-timestamp"),
          headers: { "Authorization" => "Bearer #{VALID_TOKEN}" },
          as: :json
        assert_response :unprocessable_entity
        body = JSON.parse(response.body)
        assert_equal "next_poll_utc must be a valid ISO-8601 timestamp", body["error"]

        post api_v1_telemetry_url,
          params: @valid_payload.merge(next_photo_utc: "invalid-iso-timestamp"),
          headers: { "Authorization" => "Bearer #{VALID_TOKEN}" },
          as: :json
        assert_response :unprocessable_entity
        body = JSON.parse(response.body)
        assert_equal "next_photo_utc must be a valid ISO-8601 timestamp", body["error"]
      end

      test "persists next_poll_utc and next_photo_utc when provided" do
        payload = @valid_payload.merge(
          device_id: "dev-next-poll-1",
          next_poll_utc: "2026-10-30T17:15:00Z",
          next_photo_utc: "2026-10-30T18:15:00Z"
        )

        assert_difference [ "Device.count", "TelemetryReading.count" ], 1 do
          post api_v1_telemetry_url,
            params: payload,
            headers: { "Authorization" => "Bearer #{VALID_TOKEN}" },
            as: :json
        end

        assert_response :created
        body = JSON.parse(response.body)
        reading = TelemetryReading.find(body["reading_id"])
        device = Device.find_by!(tuya_device_id: "dev-next-poll-1")

        assert_equal Time.utc(2026, 10, 30, 17, 15, 0), reading.next_poll_at
        assert_equal Time.utc(2026, 10, 30, 17, 15, 0), device.next_poll_at
        assert_equal Time.utc(2026, 10, 30, 18, 15, 0), reading.next_photo_at
        assert_equal Time.utc(2026, 10, 30, 18, 15, 0), device.next_photo_at
      end

      test "handles payload without next_poll_utc and next_photo_utc cleanly for backwards compatibility" do
        payload = @valid_payload.merge(device_id: "dev-legacy-1")
        assert_not payload.key?(:next_poll_utc)
        assert_not payload.key?(:next_photo_utc)

        post api_v1_telemetry_url,
          params: payload,
          headers: { "Authorization" => "Bearer #{VALID_TOKEN}" },
          as: :json

        assert_response :created
        body = JSON.parse(response.body)
        reading = TelemetryReading.find(body["reading_id"])
        device = Device.find_by!(tuya_device_id: "dev-legacy-1")

        assert_nil reading.next_poll_at
        assert_nil device.next_poll_at
        assert_nil reading.next_photo_at
        assert_nil device.next_photo_at
      end

      test "sanitizes and bounds alarms and raw_dps json objects" do
        many_keys = (1..80).to_h { |i| [ "dp_#{i}", "x" * 500 ] }
        payload = @valid_payload.merge(
          device_id: "dev-bounded-json",
          raw_dps: many_keys
        )

        post api_v1_telemetry_url,
          params: payload,
          headers: { "Authorization" => "Bearer #{VALID_TOKEN}" },
          as: :json

        assert_response :created
        reading = TelemetryReading.find(JSON.parse(response.body)["reading_id"])
        assert_equal Api::V1::TelemetryController::MAX_JSON_KEYS, reading.raw_dps.size
        assert_equal Api::V1::TelemetryController::MAX_JSON_STRING_BYTES, reading.raw_dps.values.first.bytesize
      end
    end
  end
end
