namespace :telemetry do
  desc "Remove all telemetry readings and reset cached device temperature stats"
  task clear: :environment do
    count = TelemetryReading.delete_all
    Device.update_all(
      last_seen_at: nil,
      last_temp_c: nil,
      last_temp_f: nil,
      last_unit: "C",
      last_relay_state: nil
    )
    puts "Cleared #{count} telemetry reading(s) and reset device stats."
  end
end
