require "test_helper"

class RefreshWeatherJobTest < ActiveJob::TestCase
  test "calls WeatherForecast.refresh!" do
    called = false
    singleton = class << WeatherForecast; self; end
    singleton.send(:alias_method, :orig_refresh!, :refresh!)
    singleton.send(:define_method, :refresh!) { called = true }

    begin
      RefreshWeatherJob.perform_now
      assert called, "Expected WeatherForecast.refresh! to be called"
    ensure
      singleton.send(:alias_method, :refresh!, :orig_refresh!)
      singleton.send(:remove_method, :orig_refresh!)
    end
  end
end
