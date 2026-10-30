class CreateDevicePhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :device_photos do |t|
      t.references :device, null: false, foreign_key: true
      t.datetime :recorded_at, null: false
      t.string :lens, null: false, default: "REAR_WIDE"
      t.integer :width
      t.integer :height
      t.float :current_temp_c
      t.string :file_path, null: false
      t.integer :byte_size, null: false

      t.timestamps
    end

    add_index :device_photos, [ :device_id, :recorded_at, :lens ], unique: true, name: "index_device_photos_on_device_recorded_at_and_lens"
    add_index :device_photos, :recorded_at
  end
end
