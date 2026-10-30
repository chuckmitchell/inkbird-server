# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_30_171031) do
  create_table "device_photos", force: :cascade do |t|
    t.integer "device_id", null: false
    t.datetime "recorded_at", null: false
    t.string "lens", default: "REAR_WIDE", null: false
    t.integer "width"
    t.integer "height"
    t.float "current_temp_c"
    t.string "file_path", null: false
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "next_photo_at"
    t.index ["device_id", "recorded_at", "lens"], name: "index_device_photos_on_device_recorded_at_and_lens", unique: true
    t.index ["device_id"], name: "index_device_photos_on_device_id"
    t.index ["recorded_at"], name: "index_device_photos_on_recorded_at"
  end

  create_table "devices", force: :cascade do |t|
    t.string "tuya_device_id", null: false
    t.string "name", default: "Cottage ITC-308"
    t.datetime "last_seen_at"
    t.float "last_temp_c"
    t.float "last_temp_f"
    t.string "last_unit", default: "C"
    t.string "last_relay_state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "next_poll_at"
    t.datetime "next_photo_at"
    t.index ["last_seen_at"], name: "index_devices_on_last_seen_at"
    t.index ["next_photo_at"], name: "index_devices_on_next_photo_at"
    t.index ["next_poll_at"], name: "index_devices_on_next_poll_at"
    t.index ["tuya_device_id"], name: "index_devices_on_tuya_device_id", unique: true
  end

  create_table "telemetry_readings", force: :cascade do |t|
    t.integer "device_id", null: false
    t.datetime "recorded_at", null: false
    t.string "unit", default: "C", null: false
    t.float "current_temp_c"
    t.float "current_temp_f"
    t.float "target_temp_c"
    t.string "relay_state", default: "unknown"
    t.integer "compressor_delay_min"
    t.float "high_alarm_limit"
    t.float "low_alarm_limit"
    t.json "alarms", default: {}
    t.json "raw_dps", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "next_poll_at"
    t.datetime "next_photo_at"
    t.index ["device_id", "recorded_at"], name: "index_telemetry_readings_on_device_id_and_recorded_at", unique: true
    t.index ["device_id"], name: "index_telemetry_readings_on_device_id"
    t.index ["recorded_at"], name: "index_telemetry_readings_on_recorded_at"
  end

  add_foreign_key "device_photos", "devices"
  add_foreign_key "telemetry_readings", "devices"
end
