require "test_helper"

class DeviceTest < ActiveSupport::TestCase
  test "requires unique tuya_device_id" do
    Device.create!(tuya_device_id: "02720007bcddc234ce20")
    duplicate = Device.new(tuya_device_id: "02720007bcddc234ce20")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:tuya_device_id], "has already been taken"
  end

  test "online? returns true when last_seen_at is within threshold" do
    device = Device.new(tuya_device_id: "dev-1", last_seen_at: 2.minutes.ago)
    assert device.online?

    device.last_seen_at = (Device::ONLINE_THRESHOLD + 1.minute).ago
    assert_not device.online?

    device.last_seen_at = nil
    assert_not device.online?
  end

  test "refresh_cached_state! updates cached fields only when reading is newest" do
    device = Device.create!(tuya_device_id: "dev-2")
    newer_time = Time.utc(2026, 10, 29, 16, 15, 0)
    older_time = Time.utc(2026, 10, 29, 16, 10, 0)

    newer_reading = device.telemetry_readings.create!(
      recorded_at: newer_time,
      unit: "C",
      current_temp_c: 22.5,
      current_temp_f: 72.5,
      relay_state: "cooling"
    )
    device.refresh_cached_state!(newer_reading)

    assert_equal newer_time, device.last_seen_at
    assert_in_delta 22.5, device.last_temp_c, 0.01
    assert_equal "cooling", device.last_relay_state

    older_reading = device.telemetry_readings.create!(
      recorded_at: older_time,
      unit: "C",
      current_temp_c: 18.0,
      current_temp_f: 64.4,
      relay_state: "idle"
    )
    device.refresh_cached_state!(older_reading)

    assert_equal newer_time, device.last_seen_at
    assert_in_delta 22.5, device.last_temp_c, 0.01
    assert_equal "cooling", device.last_relay_state
  end
end
