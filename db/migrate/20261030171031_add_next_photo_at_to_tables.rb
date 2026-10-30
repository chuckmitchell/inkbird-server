class AddNextPhotoAtToTables < ActiveRecord::Migration[8.1]
  def change
    add_column :telemetry_readings, :next_photo_at, :datetime
    add_column :device_photos, :next_photo_at, :datetime
    add_column :devices, :next_photo_at, :datetime
    add_index :devices, :next_photo_at
  end
end
