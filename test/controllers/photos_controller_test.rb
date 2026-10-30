require "test_helper"

class PhotosControllerTest < ActionDispatch::IntegrationTest
  SAMPLE_JPEG_BYTES = "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xFF\xD9".b.freeze

  teardown do
    FileUtils.rm_rf(DevicePhoto.storage_root)
  end

  test "serves stored JPEG image inline with public cache headers" do
    device = Device.create!(tuya_device_id: "02720007bcddc234ce20")
    recorded_at = Time.utc(2026, 10, 29, 16, 15, 0)
    rel_path = DevicePhoto.build_relative_path(
      tuya_device_id: device.tuya_device_id,
      recorded_at: recorded_at,
      lens: "REAR_WIDE"
    )

    photo = device.device_photos.new(
      recorded_at: recorded_at,
      lens: "REAR_WIDE",
      width: 1280,
      height: 960,
      current_temp_c: 29.0,
      file_path: rel_path
    )
    photo.write_image_bytes!(SAMPLE_JPEG_BYTES)
    photo.save!

    get photo_url(photo)
    assert_response :success
    assert_equal "image/jpeg", response.media_type
    assert_equal SAMPLE_JPEG_BYTES, response.body.b
  end

  test "returns 404 when photo record or file does not exist" do
    get photo_url(id: 999999)
    assert_response :not_found
  end
end
