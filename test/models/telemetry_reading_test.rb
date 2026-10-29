require "test_helper"

class TelemetryReadingTest < ActiveSupport::TestCase
  setup do
    @device = Device.create!(tuya_device_id: "02720007bcddc234ce20")
  end

  test "enforces uniqueness of recorded_at scoped to device" do
    timestamp = Time.utc(2026, 10, 29, 16, 15, 0)
    @device.telemetry_readings.create!(recorded_at: timestamp, unit: "C", current_temp_c: 20.0)

    duplicate = @device.telemetry_readings.build(recorded_at: timestamp, unit: "C", current_temp_c: 20.0)
    assert_not duplicate.valid?
  end

  test "active_alarms maps Tuya alarm DPs to readable labels" do
    reading = @device.telemetry_readings.create!(
      recorded_at: Time.current,
      unit: "C",
      alarms: { "111" => true, "112" => false, "113" => true }
    )

    assert_equal [ "High Temperature Alarm", "Sensor Fault Alarm" ], reading.active_alarms
  end
end
