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

  test "online? considers next_poll_at with grace period" do
    device = Device.new(
      tuya_device_id: "dev-poll-online",
      last_seen_at: 10.minutes.ago,
      next_poll_at: 50.minutes.from_now
    )
    assert device.online?

    # Within grace period (e.g., polled 65 mins ago, scheduled 5 mins ago, within 15-min grace)
    device.last_seen_at = 65.minutes.ago
    device.next_poll_at = 5.minutes.ago
    assert device.online?

    # Exceeded grace period (e.g., polled 80 mins ago, scheduled 20 mins ago, past 15-min grace)
    device.last_seen_at = 80.minutes.ago
    device.next_poll_at = 20.minutes.ago
    assert_not device.online?
  end

  test "refresh_cached_state! updates cached fields only when reading is newest" do
    device = Device.create!(tuya_device_id: "dev-2")
    newer_time = Time.utc(2026, 10, 29, 16, 15, 0)
    newer_poll_time = Time.utc(2026, 10, 29, 17, 15, 0)
    older_time = Time.utc(2026, 10, 29, 16, 10, 0)

    newer_reading = device.telemetry_readings.create!(
      recorded_at: newer_time,
      next_poll_at: newer_poll_time,
      unit: "C",
      current_temp_c: 22.5,
      current_temp_f: 72.5,
      relay_state: "cooling"
    )
    device.refresh_cached_state!(newer_reading)

    assert_equal newer_time, device.last_seen_at
    assert_equal newer_poll_time, device.next_poll_at
    assert_in_delta 22.5, device.last_temp_c, 0.01
    assert_equal "cooling", device.last_relay_state

    older_reading = device.telemetry_readings.create!(
      recorded_at: older_time,
      next_poll_at: newer_poll_time - 10.minutes,
      unit: "C",
      current_temp_c: 18.0,
      current_temp_f: 64.4,
      relay_state: "idle"
    )
    device.refresh_cached_state!(older_reading)

    assert_equal newer_time, device.last_seen_at
    assert_equal newer_poll_time, device.next_poll_at
    assert_in_delta 22.5, device.last_temp_c, 0.01
    assert_equal "cooling", device.last_relay_state
  end

  test "camera_stale? considers next_photo_at with grace period" do
    device = Device.new(tuya_device_id: "dev-camera")
    assert_not device.camera_stale?

    # Future scheduled capture: not stale
    device.next_photo_at = 30.minutes.from_now
    assert_not device.camera_stale?

    # Within grace period (e.g. 10 minutes overdue, grace period is 30 mins): not stale
    device.next_photo_at = 10.minutes.ago
    assert_not device.camera_stale?

    # Past grace period (e.g. 45 minutes overdue): stale
    device.next_photo_at = 45.minutes.ago
    assert device.camera_stale?
  end

  test "record_photo_seen! updates last_seen_at and next_photo_at" do
    device = Device.create!(tuya_device_id: "dev-record-photo")
    recorded_at = Time.utc(2026, 10, 30, 16, 0, 0)
    next_photo_at = Time.utc(2026, 10, 30, 19, 0, 0)

    device.record_photo_seen!(recorded_at, current_temp_c: 23.5, next_photo_at: next_photo_at)

    assert_equal recorded_at, device.last_seen_at
    assert_in_delta 23.5, device.last_temp_c, 0.01
    assert_equal next_photo_at, device.next_photo_at
  end

  test "refresh_cached_state! updates next_photo_at when provided on reading" do
    device = Device.create!(tuya_device_id: "dev-refresh-photo")
    recorded_at = Time.utc(2026, 10, 30, 16, 0, 0)
    next_photo_at = Time.utc(2026, 10, 30, 19, 0, 0)

    reading = device.telemetry_readings.create!(
      recorded_at: recorded_at,
      next_photo_at: next_photo_at,
      unit: "C",
      current_temp_c: 21.0,
      relay_state: "cooling"
    )
    device.refresh_cached_state!(reading)

    assert_equal next_photo_at, device.next_photo_at
  end
end
