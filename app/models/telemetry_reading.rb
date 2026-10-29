class TelemetryReading < ApplicationRecord
  VALID_UNITS = %w[C F].freeze
  VALID_RELAY_STATES = %w[cooling heating idle unknown].freeze

  belongs_to :device

  validates :recorded_at, presence: true
  validates :recorded_at, uniqueness: { scope: :device_id }
  validates :unit, presence: true, inclusion: { in: VALID_UNITS }

  scope :chronological, -> { order(recorded_at: :asc) }
  scope :recent_first, -> { order(recorded_at: :desc) }
  scope :since, ->(time) { where(recorded_at: time..) }

  def active_alarms
    return [] unless alarms.is_a?(Hash)

    labels = {
      "111" => "High Temperature Alarm",
      "112" => "Low Temperature Alarm",
      "113" => "Sensor Fault Alarm"
    }

    alarms.each_with_object([]) do |(dp, active), list|
      list << (labels[dp.to_s] || "Alarm DP #{dp}") if active == true
    end
  end
end
