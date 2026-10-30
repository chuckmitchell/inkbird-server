namespace :photos do
  desc "Archive and remove device photos older than ARCHIVE_DAYS (default: 30)"
  task archive: :environment do
    days = (ENV["ARCHIVE_DAYS"].presence || 30).to_i
    cutoff = days.days.ago
    archive_root = Pathname.new(ENV["ARCHIVE_DIR"].presence || Rails.root.join("storage/photos_archive"))

    expired_photos = DevicePhoto.older_than(cutoff)
    total = expired_photos.count

    if total.zero?
      puts "No photos older than #{days} days (cutoff: #{cutoff.utc.iso8601})."
      next
    end

    archived_count = 0
    expired_photos.find_each do |photo|
      if photo.file_exists?
        dest_path = archive_root.join(photo.file_path)
        FileUtils.mkdir_p(File.dirname(dest_path))
        FileUtils.mv(photo.absolute_file_path, dest_path)
      end

      photo.destroy!
      archived_count += 1
    end

    puts "Archived #{archived_count} photo(s) older than #{days} days to #{archive_root}."
  end
end
