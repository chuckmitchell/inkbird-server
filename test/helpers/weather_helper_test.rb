require "test_helper"

class WeatherHelperTest < ActionView::TestCase
  test "renders clear-day svg" do
    svg = weather_icon_svg("clear-day")
    assert_includes svg, "<svg"
    assert_includes svg, "#fbbf24"
  end

  test "renders clear-night svg" do
    svg = weather_icon_svg("clear-night")
    assert_includes svg, "<svg"
    assert_includes svg, "#818cf8"
  end

  test "renders partly cloudy svgs" do
    assert_includes weather_icon_svg("partly-cloudy-day"), "<svg"
    assert_includes weather_icon_svg("partly-cloudy-night"), "<svg"
  end

  test "renders fallback for unknown icon" do
    svg = weather_icon_svg("non-existent-code")
    assert_includes svg, "<svg"
  end
end
