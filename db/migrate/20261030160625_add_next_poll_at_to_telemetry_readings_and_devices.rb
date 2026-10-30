class AddNextPollAtToTelemetryReadingsAndDevices < ActiveRecord::Migration[8.1]
  def change
    add_column :telemetry_readings, :next_poll_at, :datetime
    add_column :devices, :next_poll_at, :datetime
    add_index :devices, :next_poll_at
  end
end
