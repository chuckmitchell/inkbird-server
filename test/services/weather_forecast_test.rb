require "test_helper"

class WeatherForecastTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  test "converts degrees to cardinal direction accurately" do
    assert_equal "N", WeatherForecast.degrees_to_cardinal(0)
    assert_equal "N", WeatherForecast.degrees_to_cardinal(360)
    assert_equal "NE", WeatherForecast.degrees_to_cardinal(45)
    assert_equal "E", WeatherForecast.degrees_to_cardinal(90)
    assert_equal "SE", WeatherForecast.degrees_to_cardinal(135)
    assert_equal "S", WeatherForecast.degrees_to_cardinal(180)
    assert_equal "SW", WeatherForecast.degrees_to_cardinal(225)
    assert_equal "W", WeatherForecast.degrees_to_cardinal(270)
    assert_equal "NW", WeatherForecast.degrees_to_cardinal(315)
    assert_equal "NNW", WeatherForecast.degrees_to_cardinal(337.5)
    assert_nil WeatherForecast.degrees_to_cardinal(nil)
  end

  test "converts celsius to fahrenheit" do
    assert_equal 32.0, WeatherForecast.c_to_f(0.0)
    assert_equal 68.0, WeatherForecast.c_to_f(20.0)
    assert_equal 54.3, WeatherForecast.c_to_f(12.4)
    assert_nil WeatherForecast.c_to_f(nil)
  end

  test "parses payload into clean hash" do
    sample_payload = {
      "current" => {
        "temperature_2m" => 12.4,
        "weather_code" => 2,
        "is_day" => 1,
        "wind_speed_10m" => 18.2,
        "wind_direction_10m" => 315.0
      },
      "daily" => {
        "temperature_2m_max" => [15.1],
        "temperature_2m_min" => [6.2]
      }
    }

    result = WeatherForecast.send(:parse_payload, sample_payload)

    assert_equal "Lunenburg, NS", result[:location_name]
    assert_equal 12.4, result[:temp_c]
    assert_equal 54.3, result[:temp_f]
    assert_equal "Partly cloudy", result[:condition_label]
    assert_equal "partly-cloudy-day", result[:icon_key]
    assert_equal 15.1, result[:high_c]
    assert_equal 59.2, result[:high_f]
    assert_equal 6.2, result[:low_c]
    assert_equal 43.2, result[:low_f]
    assert_equal 18, result[:wind_speed_kmh]
    assert_equal "NW", result[:wind_direction_cardinal]
  end

  test "handles night icon when is_day is 0" do
    sample_payload = {
      "current" => {
        "temperature_2m" => 8.0,
        "weather_code" => 2,
        "is_day" => 0,
        "wind_speed_10m" => 10.0,
        "wind_direction_10m" => 180.0
      },
      "daily" => {
        "temperature_2m_max" => [12.0],
        "temperature_2m_min" => [5.0]
      }
    }

    result = WeatherForecast.send(:parse_payload, sample_payload)
    assert_equal "partly-cloudy-night", result[:icon_key]
  end
end
