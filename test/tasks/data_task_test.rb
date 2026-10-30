require "test_helper"
require "rake"

class DataTaskTest < ActiveSupport::TestCase
  setup do
    @rake = Rake::Application.new
    Rake.application = @rake
    Rails.application.load_tasks

    @device = Device.create!(
      tuya_device_id: "test-device-123",
      name: "Test Cottage",
      last_seen_at: Time.current,
      last_temp_c: 24.5,
      last_temp_f: 76.1,
      last_relay_state: "idle"
    )

    @reading = @device.telemetry_readings.create!(
      recorded_at: Time.current,
      unit: "C",
      current_temp_c: 24.5
    )

    @photo = @device.device_photos.create!(
      recorded_at: Time.current,
      lens: "REAR_WIDE",
      width: 100,
      height: 100,
      byte_size: 4,
      file_path: "test-device-123/2026-10-30/test.jpg"
    )
    @photo.write_image_bytes!("fake")
  end

  teardown do
    FileUtils.rm_rf(DevicePhoto.storage_root)
    ENV.delete("DELETE_DEVICES")
  end

  test "data:reset removes telemetry readings and photos, and resets device stats" do
    assert File.exist?(@photo.absolute_file_path)

    assert_output(/Purged 1 telemetry reading\(s\), 1 photo\(s\), and reset cached state for 1 device\(s\)/) do
      Rake::Task["data:reset"].invoke
    end

    assert_equal 0, TelemetryReading.count
    assert_equal 0, DevicePhoto.count
    assert_not File.exist?(@photo.absolute_file_path)

    @device.reload
    assert_nil @device.last_seen_at
    assert_nil @device.last_temp_c
    assert_nil @device.last_temp_f
    assert_nil @device.last_relay_state
  end

  test "data:reset deletes device records when DELETE_DEVICES is set" do
    ENV["DELETE_DEVICES"] = "1"

    assert_output(/Purged 1 telemetry reading\(s\), 1 photo\(s\), and deleted 1 device\(s\)/) do
      Rake::Task["data:reset"].invoke
    end

    assert_equal 0, TelemetryReading.count
    assert_equal 0, DevicePhoto.count
    assert_equal 0, Device.count
  end
end
