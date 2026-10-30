class Device < ApplicationRecord
  ONLINE_THRESHOLD = 130.minutes

  has_many :telemetry_readings, dependent: :destroy
  has_many :device_photos, dependent: :destroy

  validates :tuya_device_id, presence: true, uniqueness: true

  def to_param
    tuya_device_id
  end

  def online?
    last_seen_at.present? && last_seen_at >= ONLINE_THRESHOLD.ago
  end

  def effective_last_temp_f
    last_temp_f.presence || (last_temp_c.present? ? ((last_temp_c * 9.0 / 5.0) + 32.0).round(1) : nil)
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

  def record_photo_seen!(recorded_at, current_temp_c: nil)
    new_last_seen_at = [ last_seen_at, recorded_at ].compact.max
    attrs = { last_seen_at: new_last_seen_at }
    if current_temp_c.present? && (last_seen_at.nil? || recorded_at >= last_seen_at)
      attrs[:last_temp_c] = current_temp_c
    end
    update!(attrs)
  end
end
