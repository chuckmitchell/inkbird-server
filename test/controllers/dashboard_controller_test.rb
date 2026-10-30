require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "renders empty state when no devices exist" do
    get root_url
    assert_response :success
    assert_select "h1", text: /Cottage ITC-308/
    assert_select "h2", text: /No Thermostat Telemetry Received Yet/
  end

  test "renders device status, online badge, and range filters when readings exist" do
    device = Device.create!(
      tuya_device_id: "02720007bcddc234ce20",
      name: "Cottage ITC-308"
    )
    reading = device.telemetry_readings.create!(
      recorded_at: 2.minutes.ago,
      unit: "C",
      current_temp_c: 21.4,
      current_temp_f: 70.5,
      target_temp_c: 8.0,
      relay_state: "cooling",
      compressor_delay_min: 3,
      high_alarm_limit: 35.0,
      low_alarm_limit: 0.0,
      alarms: { "111" => false, "112" => false, "113" => false }
    )
    device.refresh_cached_state!(reading)

    get root_url
    assert_response :success
    assert_select "span", text: /Online/
    assert_select "p", text: /21\.4°C/
    assert_select "a", text: "24h"
    assert_select "a", text: "7d"
    assert_select "a", text: "30d"

    get root_url(range: "7d")
    assert_response :success
    assert_select "h2", text: /Last 7 Days Summary/
  end

  test "renders latest photo and recent captures on the dashboard" do
    device = Device.create!(tuya_device_id: "02720007bcddc234ce20", name: "Cottage ITC-308")

    photo1 = device.device_photos.create!(
      recorded_at: 2.hours.ago,
      lens: "REAR_WIDE",
      width: 1280,
      height: 960,
      current_temp_c: 24.5,
      file_path: "02720007bcddc234ce20/2026-10-29/photo1.jpg",
      byte_size: 1024
    )
    photo2 = device.device_photos.create!(
      recorded_at: 1.hour.ago,
      lens: "REAR_WIDE",
      width: 1280,
      height: 960,
      current_temp_c: 29.0,
      file_path: "02720007bcddc234ce20/2026-10-29/photo2.jpg",
      byte_size: 1024
    )

    get root_url
    assert_response :success
    assert_select "h2", text: "Latest Cottage Photo"
    assert_select "img[src='#{photo_path(photo2)}']"
    assert_select "img[src='#{photo_path(photo1)}']"
    assert_select "span", text: "29.0°C"
  end
end
