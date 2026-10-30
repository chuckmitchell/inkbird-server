require "net/http"
require "json"

class WeatherForecast
  CACHE_KEY = "env_canada_current_weather_v1"
  CACHE_TTL = 12.hours # Disappear after 12 hours if upstream weather API remains unavailable
  CACHE_REFRESH_INTERVAL = 1.hour

  DEFAULT_LATITUDE = 44.3769
  DEFAULT_LONGITUDE = -64.3188
  DEFAULT_LOCATION_NAME = "Lunenburg, NS"

  # Environment Canada iconCode to SVG icon key & condition fallback mapping
  EC_ICON_CODES = {
    "00" => { icon: "clear-day", label: "Sunny" },
    "01" => { icon: "clear-day", label: "Mainly sunny" },
    "02" => { icon: "partly-cloudy-day", label: "Partly cloudy" },
    "03" => { icon: "partly-cloudy-day", label: "Mainly cloudy" },
    "04" => { icon: "partly-cloudy-day", label: "Increasing cloud" },
    "05" => { icon: "partly-cloudy-day", label: "Clearing" },
    "06" => { icon: "rain", label: "Showers" },
    "07" => { icon: "sleet", label: "Rain or snow" },
    "08" => { icon: "snow", label: "Flurries" },
    "09" => { icon: "rain", label: "Chance of showers" },
    "10" => { icon: "cloudy", label: "Cloudy" },
    "11" => { icon: "rain", label: "Periods of rain" },
    "12" => { icon: "rain", label: "Periods of rain" },
    "13" => { icon: "heavy-rain", label: "Heavy rain" },
    "14" => { icon: "sleet", label: "Freezing rain" },
    "15" => { icon: "sleet", label: "Freezing drizzle" },
    "16" => { icon: "snow", label: "Periods of snow" },
    "17" => { icon: "snow", label: "Periods of snow" },
    "18" => { icon: "snow", label: "Heavy snow" },
    "19" => { icon: "thunderstorm", label: "Thunderstorm" },
    "22" => { icon: "partly-cloudy-day", label: "A mix of sun and cloud" },
    "23" => { icon: "fog", label: "Haze" },
    "24" => { icon: "fog", label: "Fog" },
    "25" => { icon: "snow", label: "Drifting snow" },
    "26" => { icon: "snow", label: "Ice crystals" },
    "27" => { icon: "sleet", label: "Ice pellets" },
    "28" => { icon: "drizzle", label: "Drizzle" },
    "29" => { icon: "partly-cloudy-day", label: "A mix of sun and cloud" },
    "30" => { icon: "clear-night", label: "Clear" },
    "31" => { icon: "clear-night", label: "Mainly clear" },
    "32" => { icon: "partly-cloudy-night", label: "Partly cloudy" },
    "33" => { icon: "partly-cloudy-night", label: "Mainly cloudy" },
    "34" => { icon: "partly-cloudy-night", label: "Increasing cloud" },
    "35" => { icon: "partly-cloudy-night", label: "Clearing" },
    "36" => { icon: "rain", label: "Chance of showers" },
    "37" => { icon: "sleet", label: "Chance of flurries or rain" },
    "38" => { icon: "snow", label: "Chance of flurries" },
    "39" => { icon: "thunderstorm", label: "Thunderstorm" },
    "40" => { icon: "snow", label: "Blowing snow" },
    "41" => { icon: "thunderstorm", label: "Funnel cloud" },
    "42" => { icon: "thunderstorm", label: "Tornado" },
    "43" => { icon: "cloudy", label: "Windy" },
    "44" => { icon: "fog", label: "Smoke" },
    "45" => { icon: "fog", label: "Dense fog" },
    "46" => { icon: "thunderstorm", label: "Thunderstorm" },
    "47" => { icon: "thunderstorm", label: "Thunderstorm" },
    "48" => { icon: "fog", label: "Waterspout" }
  }.freeze

  class << self
    def current(force_refresh: false)
      if force_refresh
        refresh!
      else
        cached = Rails.cache.read(CACHE_KEY)
        cached.presence || refresh!
      end
    rescue => e
      Rails.logger.warn("[WeatherForecast] Failed to fetch current weather: #{e.class}: #{e.message}")
      Rails.cache.read(CACHE_KEY)
    end

    def refresh!
      data = fetch_from_api
      Rails.cache.write(CACHE_KEY, data, expires_in: CACHE_TTL) if data
      data
    rescue => e
      Rails.logger.warn("[WeatherForecast] Failed to refresh weather: #{e.class}: #{e.message}")
      nil
    end

    def latitude
      (ENV["WEATHER_LATITUDE"].presence || DEFAULT_LATITUDE).to_f
    end

    def longitude
      (ENV["WEATHER_LONGITUDE"].presence || DEFAULT_LONGITUDE).to_f
    end

    def location_name
      ENV["WEATHER_LOCATION_NAME"].presence || DEFAULT_LOCATION_NAME
    end

    def forecast_url
      ENV["WEATHER_FORECAST_URL"].presence || "https://weather.gc.ca/en/location/index.html?coords=#{latitude},#{longitude}"
    end

    def c_to_f(c)
      return nil unless c
      ((c * 9.0 / 5.0) + 32.0).round(1)
    end

    private

    def fetch_from_api
      uri = URI(forecast_url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 6

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
      request["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"

      response = http.request(request)
      return nil unless response.is_a?(Net::HTTPSuccess)

      parse_html_payload(response.body)
    end

    def parse_html_payload(html)
      match = html.match(/window\.__INITIAL_STATE__=(.+?);\(function/m)
      return nil unless match

      state = JSON.parse(match[1])
      location_container = state.dig("location", "location") || {}
      loc_data = location_container.values.first
      return nil unless loc_data

      obs = loc_data["obs"] || {}
      hourly = loc_data["hourly"] || []
      daily_forecasts = loc_data.dig("forecast", "daily") || []

      # Temperatures
      temp_c = obs.dig("temperature", "metric")&.to_f&.round(1)
      temp_f = obs.dig("temperature", "imperial")&.to_f&.round(1) || c_to_f(temp_c)

      # High & Low from daily forecast
      high_c = daily_forecasts[0]&.dig("temperature", "periodHigh")&.to_f&.round(1) ||
               daily_forecasts[0]&.dig("temperature", "metric")&.to_f&.round(1)
      low_c = daily_forecasts[1]&.dig("temperature", "periodLow")&.to_f&.round(1) ||
              daily_forecasts[1]&.dig("temperature", "metric")&.to_f&.round(1)
      high_f = daily_forecasts[0]&.dig("temperature", "imperial")&.to_f&.round(1) || c_to_f(high_c)
      low_f = daily_forecasts[1]&.dig("temperature", "imperial")&.to_f&.round(1) || c_to_f(low_c)

      # Wind
      wind_speed_kmh = obs.dig("windSpeed", "metric")&.to_i
      wind_cardinal = obs["windDirection"].presence

      # Condition label and icon
      icon_code = obs["iconCode"].to_s.rjust(2, "0")
      condition_label = obs["condition"].presence ||
                        hourly[0]&.dig("condition").presence ||
                        EC_ICON_CODES[icon_code]&.dig(:label) ||
                        daily_forecasts[0]&.dig("summary").presence ||
                        "Current Conditions"

      icon_key = EC_ICON_CODES[icon_code]&.dig(:icon) ||
                 EC_ICON_CODES[hourly[0]&.dig("iconCode").to_s.rjust(2, "0")]&.dig(:icon) ||
                 "partly-cloudy-day"

      station_name = obs["observedAt"].presence || location_name

      {
        location_name: location_name,
        station_name: station_name,
        forecast_url: forecast_url,
        fetched_at: Time.current.iso8601,
        condition_label: condition_label,
        icon_key: icon_key,
        temp_c: temp_c,
        temp_f: temp_f,
        high_c: high_c,
        high_f: high_f,
        low_c: low_c,
        low_f: low_f,
        wind_speed_kmh: wind_speed_kmh,
        wind_direction_cardinal: wind_cardinal
      }.with_indifferent_access
    end
  end
end
