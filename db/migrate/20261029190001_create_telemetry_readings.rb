class CreateTelemetryReadings < ActiveRecord::Migration[8.1]
  def change
    create_table :telemetry_readings do |t|
      t.references :device, null: false, foreign_key: true
      t.datetime :recorded_at, null: false
      t.string :unit, null: false, default: "C"
      t.float :current_temp_c
      t.float :current_temp_f
      t.float :target_temp_c
      t.string :relay_state, default: "unknown"
      t.integer :compressor_delay_min
      t.float :high_alarm_limit
      t.float :low_alarm_limit
      t.json :alarms, default: {}
      t.json :raw_dps, default: {}

      t.timestamps
    end

    add_index :telemetry_readings, [ :device_id, :recorded_at ], unique: true
    add_index :telemetry_readings, :recorded_at
  end
end
