require "test_helper"

class DevicePhotoTest < ActiveSupport::TestCase
  SAMPLE_JPEG_BYTES = "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xFF\xD9".b.freeze

  teardown do
    FileUtils.rm_rf(DevicePhoto.storage_root)
  end

  test "writes image bytes to disk and deletes file on destroy" do
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

    assert photo.file_exists?
    assert_equal SAMPLE_JPEG_BYTES.bytesize, photo.byte_size
    assert_equal SAMPLE_JPEG_BYTES, File.binread(photo.absolute_file_path)

    full_path = photo.absolute_file_path
    photo.destroy!
    assert_not File.exist?(full_path)
  end

  test "enforces uniqueness of recorded_at scoped to device and lens" do
    device = Device.create!(tuya_device_id: "02720007bcddc234ce20")
    recorded_at = Time.utc(2026, 10, 29, 16, 15, 0)

    device.device_photos.create!(
      recorded_at: recorded_at,
      lens: "REAR_WIDE",
      file_path: "02720007bcddc234ce20/2026-10-29/20261029T161500Z_REAR_WIDE.jpg",
      byte_size: 128
    )

    duplicate = device.device_photos.new(
      recorded_at: recorded_at,
      lens: "REAR_WIDE",
      file_path: "02720007bcddc234ce20/2026-10-29/20261029T161500Z_REAR_WIDE.jpg",
      byte_size: 128
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:recorded_at], "has already been taken"
  end

  test "rejects path traversal outside storage_root" do
    device = Device.create!(tuya_device_id: "02720007bcddc234ce20")
    photo = device.device_photos.new(
      recorded_at: Time.utc(2026, 10, 29, 16, 15, 0),
      lens: "REAR_WIDE",
      file_path: "../../etc/passwd",
      byte_size: 128
    )

    assert_not photo.safe_file_path?
    assert_not photo.file_exists?
    assert_raises(ArgumentError) do
      photo.write_image_bytes!(SAMPLE_JPEG_BYTES)
    end
  end
end
