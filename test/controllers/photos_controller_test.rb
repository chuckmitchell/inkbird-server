require "test_helper"

class PhotosControllerTest < ActionDispatch::IntegrationTest
  SAMPLE_JPEG_BYTES = "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xFF\xD9".b.freeze

  teardown do
    FileUtils.rm_rf(DevicePhoto.storage_root)
  end

  test "serves stored JPEG image inline with public cache headers" do
    device = Device.create!(tuya_device_id: "02720007bcddc234ce20")
    recorded_at = Time.utc(2026, 10, 29, 16, 15, 0)
    rel_path = DevicePhoto.build_relative_path(
      tuya_device_id: device.tuya_device_id,
      recorded_at: recorded_at,
      lens: "REAR_WIDE"
    )

    photo = device.device_photos.new(
      recorded_at: recorded_at,
      lens: "REAR_WIDE",
      width: 1280,
      height: 960,
      current_temp_c: 29.0,
      file_path: rel_path
    )
    photo.write_image_bytes!(SAMPLE_JPEG_BYTES)
    photo.save!

    get photo_url(photo)
    assert_response :success
    assert_equal "image/jpeg", response.media_type
    assert_equal SAMPLE_JPEG_BYTES, response.body.b
  end

  test "returns 404 when photo record or file does not exist" do
    get photo_url(id: 999999)
    assert_response :not_found
  end

  test "index lists previous photos grouped by date with 24h time and temperature" do
    device = Device.create!(tuya_device_id: "02720007bcddc234ce20", name: "Cottage ITC-308", last_seen_at: Time.current)
    t_today = Time.current.utc.change(hour: 14, min: 30)
    t_yesterday = 1.day.ago.utc.change(hour: 9, min: 15)

    photo1 = create_test_photo(device, recorded_at: t_today, temp: 22.4)
    photo2 = create_test_photo(device, recorded_at: t_yesterday, temp: 18.1)

    get device_photos_url(device)
    assert_response :success

    # Header and navigation
    assert_select "h1", text: /Photo History/
    assert_select "a[href=?]", root_path(device_id: device.tuya_device_id), text: /Back to Dashboard/

    # Date groupings
    assert_select "h2", text: "Today"
    assert_select "h2", text: "Yesterday"

    # Photo cards details
    assert_select "a[target='_blank'][href=?]", photo_path(photo1)
    assert_select "span", text: t_today.strftime("%H:%M UTC")
    assert_select "span", text: "22.4°C"
    assert_select "span", text: t_yesterday.strftime("%H:%M UTC")
    assert_select "span", text: "18.1°C"
  end

  test "index limits initial view to 3 distinct days and provides load more link" do
    device = Device.create!(tuya_device_id: "02720007bcddc234ce20", name: "Cottage ITC-308")

    # Create photos spanning 4 distinct days
    d1 = 1.day.ago.utc
    d2 = 2.days.ago.utc
    d3 = 3.days.ago.utc
    d4 = 4.days.ago.utc

    create_test_photo(device, recorded_at: d1, temp: 20.0)
    create_test_photo(device, recorded_at: d2, temp: 19.0)
    create_test_photo(device, recorded_at: d3, temp: 18.0)
    p4 = create_test_photo(device, recorded_at: d4, temp: 17.0)

    # Initial page should show 3 days only
    get device_photos_url(device)
    assert_response :success

    assert_select "a[href=?]", device_photos_path(device, page: 2), text: /Load 3 more days/
    assert_select "a[href=?]", photo_path(p4), count: 0

    # Loading page 2 fetches the remaining day
    get device_photos_url(device, page: 2)
    assert_response :success
    assert_select "a[href=?]", photo_path(p4), count: 1
    assert_select "span", text: "17.0°C"
  end

  test "index handles Turbo Frame load more requests" do
    device = Device.create!(tuya_device_id: "02720007bcddc234ce20", name: "Cottage ITC-308")

    d1 = 1.day.ago.utc
    d2 = 2.days.ago.utc
    d3 = 3.days.ago.utc
    d4 = 4.days.ago.utc

    create_test_photo(device, recorded_at: d1, temp: 20.0)
    create_test_photo(device, recorded_at: d2, temp: 19.0)
    create_test_photo(device, recorded_at: d3, temp: 18.0)
    p4 = create_test_photo(device, recorded_at: d4, temp: 17.0)

    get device_photos_url(device, page: 2), headers: { "Turbo-Frame" => "photos_page_2" }
    assert_response :success

    assert_select "turbo-frame#photos_page_2" do
      assert_select "a[href=?]", photo_path(p4)
      assert_select "p", text: "No older photos found."
    end
  end

  test "index redirects to root when device is not found" do
    get device_photos_url(device_id: "nonexistent_device")
    assert_redirected_to root_path
  end

  private

  def create_test_photo(device, recorded_at:, temp: 20.0, lens: "REAR_WIDE")
    rel_path = DevicePhoto.build_relative_path(
      tuya_device_id: device.tuya_device_id,
      recorded_at: recorded_at,
      lens: lens
    )

    photo = device.device_photos.new(
      recorded_at: recorded_at,
      lens: lens,
      width: 1280,
      height: 960,
      current_temp_c: temp,
      file_path: rel_path
    )
    photo.write_image_bytes!(SAMPLE_JPEG_BYTES)
    photo.save!
    photo
  end
end
