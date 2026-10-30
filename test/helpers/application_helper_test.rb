require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "friendly_timestamp formats in ADT during daylight saving time" do
    # 2026-10-30 14:50:00 UTC -> 11:50:00 ADT (UTC-3)
    time = Time.utc(2026, 10, 30, 14, 50, 0)
    assert_equal "Friday October 30, 2026 - 11:50am (ADT)", friendly_timestamp(time)
    assert_equal "Friday October 30, 2026 - 11:50am (ADT)", format_timestamp(time)
    assert_equal "Friday October 30, 2026 - 11:50am (ADT)", atlantic_timestamp(time)
  end

  test "friendly_timestamp locks past dates to AST during standard time" do
    # 2026-12-15 15:50:00 UTC -> 11:50:00 AST (UTC-4)
    time = Time.utc(2026, 12, 15, 15, 50, 0)
    assert_equal "Tuesday December 15, 2026 - 11:50am (AST)", friendly_timestamp(time)
    assert_equal "Tuesday December 15, 2026 - 11:50am (AST)", format_timestamp(time)
    assert_equal "Tuesday December 15, 2026 - 11:50am (AST)", atlantic_timestamp(time)
  end

  test "friendly_timestamp handles string timestamps and nil" do
    assert_equal "Friday October 30, 2026 - 11:50am (ADT)", friendly_timestamp("2026-10-30T14:50:00Z")
    assert_equal "", friendly_timestamp(nil)
    assert_equal "", friendly_timestamp("")
  end

  test "friendly_timestamp_short formats compact date and time for small spaces" do
    # 2026-10-30 14:50:00 UTC -> 11:50:00 ADT
    time = Time.utc(2026, 10, 30, 14, 50, 0)
    assert_equal "Fri, Oct 30, 2026 - 11:50am", friendly_timestamp_short(time)
    assert_equal "Fri, Oct 30, 2026 - 11:50am", format_timestamp_short(time)
    assert_equal "Fri, Oct 30, 2026 - 11:50am", short_timestamp(time)
    assert_equal "Fri, Oct 30, 2026 - 11:50am", atlantic_timestamp_short(time)
  end

  test "friendly_timestamp_short locks past dates to active time zone offset" do
    # 2026-12-15 15:50:00 UTC -> 11:50:00 AST (-4h offset)
    time = Time.utc(2026, 12, 15, 15, 50, 0)
    assert_equal "Tue, Dec 15, 2026 - 11:50am", friendly_timestamp_short(time)
  end

  test "friendly_timestamp_short handles string timestamps and nil" do
    assert_equal "Fri, Oct 30, 2026 - 11:50am", friendly_timestamp_short("2026-10-30T14:50:00Z")
    assert_equal "", friendly_timestamp_short(nil)
    assert_equal "", friendly_timestamp_short("")
  end
end
