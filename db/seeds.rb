# Seed sample Cottage ITC-308 telemetry in development when the database is empty
if Rails.env.development? && Device.count.zero?
  device = Device.create!(
    tuya_device_id: "02720007bcddc234ce20",
    name: "Cottage ITC-308"
  )

  now = Time.current.utc.change(sec: 0)
  (0..288).reverse_each do |step|
    recorded_at = now - (step * 5).minutes
    # Smooth diurnal sine wave around 19.5°C
    temp_c = (19.5 + 3.2 * Math.sin(step / 18.0)).round(1)
    temp_f = (temp_c * 9.0 / 5.0 + 32.0).round(1)

    reading = device.telemetry_readings.create!(
      recorded_at: recorded_at,
      unit: "C",
      current_temp_c: temp_c,
      current_temp_f: temp_f,
      target_temp_c: 8.0,
      relay_state: temp_c > 21.0 ? "cooling" : "idle",
      compressor_delay_min: 3,
      high_alarm_limit: 35.0,
      low_alarm_limit: 0.0,
      alarms: { "111" => false, "112" => false, "113" => false },
      raw_dps: {
        "101" => "C",
        "104" => (temp_c * 10).to_i,
        "106" => 80,
        "108" => 3,
        "109" => 350,
        "110" => 0,
        "111" => false,
        "112" => false,
        "113" => false,
        "115" => temp_c > 21.0 ? "1" : "3",
        "116" => (temp_f * 10).to_i
      }
    )
    device.refresh_cached_state!(reading) if step.zero?
  end
end
