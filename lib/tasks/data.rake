namespace :data do
  desc "Purge all telemetry readings and photos, and reset device stats (set DELETE_DEVICES=1 to also delete device records)"
  task reset: :environment do
    photo_count = DevicePhoto.count
    telemetry_count = TelemetryReading.count
    device_count = Device.count

    # 1. Destroy device photos and remove physical files
    DevicePhoto.find_each(&:destroy)
    if Dir.exist?(DevicePhoto.storage_root)
      FileUtils.rm_rf(Dir.glob(DevicePhoto.storage_root.join("*")))
    end

    # 2. Delete telemetry readings
    TelemetryReading.delete_all

    # 3. Reset or delete devices
    if ENV["DELETE_DEVICES"].to_s.downcase.in?(%w[true 1 yes])
      Device.destroy_all
      puts "Purged #{telemetry_count} telemetry reading(s), #{photo_count} photo(s), and deleted #{device_count} device(s)."
    else
      Device.update_all(
        last_seen_at: nil,
        last_temp_c: nil,
        last_temp_f: nil,
        last_unit: "C",
        last_relay_state: nil
      )
      puts "Purged #{telemetry_count} telemetry reading(s), #{photo_count} photo(s), and reset cached state for #{device_count} device(s)."
    end
  end
end

desc "Alias for data:reset"
task "reset:all" => "data:reset"
