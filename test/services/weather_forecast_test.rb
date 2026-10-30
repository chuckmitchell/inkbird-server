require "test_helper"

class WeatherForecastTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  test "converts celsius to fahrenheit" do
    assert_equal 32.0, WeatherForecast.c_to_f(0.0)
    assert_equal 68.0, WeatherForecast.c_to_f(20.0)
    assert_equal 54.3, WeatherForecast.c_to_f(12.4)
    assert_nil WeatherForecast.c_to_f(nil)
  end

  test "parses Environment Canada HTML payload correctly" do
    fake_state = {
      "location" => {
        "location" => {
          "44.37700000--64.31700000" => {
            "obs" => {
              "observedAt" => "Lunenburg",
              "iconCode" => "02",
              "condition" => "",
              "temperature" => { "metric" => "15", "imperial" => "59" },
              "windSpeed" => { "metric" => "12" },
              "windDirection" => "SSW"
            },
            "hourly" => [
              { "condition" => "A mix of sun and cloud", "iconCode" => "02" }
            ],
            "forecast" => {
              "daily" => [
                { "periodLabel" => "Today", "temperature" => { "periodHigh" => 16, "imperial" => "61" }, "summary" => "A few showers" },
                { "periodLabel" => "Tonight", "temperature" => { "periodLow" => 5, "imperial" => "41" } }
              ]
            }
          }
        }
      }
    }

    fake_html = "<!DOCTYPE html><html><script>window.__INITIAL_STATE__=#{fake_state.to_json};(function(){})();</script></html>"

    result = WeatherForecast.send(:parse_html_payload, fake_html)

    assert_not_nil result
    assert_equal "Lunenburg, NS", result[:location_name]
    assert_equal 15.0, result[:temp_c]
    assert_equal 59.0, result[:temp_f]
    assert_equal 16.0, result[:high_c]
    assert_equal 61.0, result[:high_f]
    assert_equal 5.0, result[:low_c]
    assert_equal 41.0, result[:low_f]
    assert_equal 12, result[:wind_speed_kmh]
    assert_equal "SSW", result[:wind_direction_cardinal]
    assert_equal "A mix of sun and cloud", result[:condition_label]
    assert_equal "partly-cloudy-day", result[:icon_key]
  end

  test "returns nil gracefully when HTML format is invalid" do
    assert_nil WeatherForecast.send(:parse_html_payload, "<html>No state here</html>")
  end
end
