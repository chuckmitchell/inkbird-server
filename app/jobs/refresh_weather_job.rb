class RefreshWeatherJob < ApplicationJob
  queue_as :default

  def perform
    WeatherForecast.refresh!
  end
end
