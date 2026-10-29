class Device < ApplicationRecord
  ONLINE_THRESHOLD = 5.minutes

  has_many :telemetry_readings, dependent: :destroy

  validates :tuya_device_id, presence: true, uniqueness: true

  def online?
    last_seen_at.present? && last_seen_at >= ONLINE_THRESHOLD.ago
  end

  def refresh_cached_state!(reading)
    new_last_seen_at = [ last_seen_at, reading.recorded_at ].compact.max

    if last_seen_at.nil? || reading.recorded_at >= last_seen_at
      update!(
        last_seen_at: new_last_seen_at,
        last_temp_c: reading.current_temp_c,
        last_temp_f: reading.current_temp_f,
        last_unit: reading.unit.presence || "C",
        last_relay_state: reading.relay_state
      )
    else
      update!(last_seen_at: new_last_seen_at)
    end
  end
end
