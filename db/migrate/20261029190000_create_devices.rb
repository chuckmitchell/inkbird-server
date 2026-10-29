class CreateDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :devices do |t|
      t.string :tuya_device_id, null: false
      t.string :name, default: "Cottage ITC-308"
      t.datetime :last_seen_at
      t.float :last_temp_c
      t.float :last_temp_f
      t.string :last_unit, default: "C"
      t.string :last_relay_state

      t.timestamps
    end

    add_index :devices, :tuya_device_id, unique: true
    add_index :devices, :last_seen_at
  end
end
