require "net/http"
require "json"

class WeatherForecast
  CACHE_KEY = "open_meteo_current_weather_v1"
  CACHE_TTL = 12.hours # Disappear after 12 hours if upstream weather API remains unavailable
  CACHE_REFRESH_INTERVAL = 1.hour

  DEFAULT_LATITUDE = 44.3769
  DEFAULT_LONGITUDE = -64.3188
  DEFAULT_LOCATION_NAME = "Lunenburg, NS"
  DEFAULT_TIMEZONE = "America/Halifax"

  CARDINAL_DIRECTIONS = %w[N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW].freeze

  # Mapping of WMO weather interpretation codes (WW) to condition text and icon key
  # https://open-meteo.com/en/docs
  WMO_CODES = {
    0 => { label: "Clear sky", icon_day: "clear-day", icon_night: "clear-night" },
    1 => { label: "Mainly clear", icon_day: "clear-day", icon_night: "clear-night" },
    2 => { label: "Partly cloudy", icon_day: "partly-cloudy-day", icon_night: "partly-cloudy-night" },
    3 => { label: "Overcast", icon_day: "cloudy", icon_night: "cloudy" },
    45 => { label: "Fog", icon_day: "fog", icon_night: "fog" },
    48 => { label: "Depositing rime fog", icon_day: "fog", icon_night: "fog" },
    51 => { label: "Light drizzle", icon_day: "drizzle", icon_night: "drizzle" },
    53 => { label: "Moderate drizzle", icon_day: "drizzle", icon_night: "drizzle" },
    55 => { label: "Dense drizzle", icon_day: "drizzle", icon_night: "drizzle" },
    56 => { label: "Freezing drizzle", icon_day: "sleet", icon_night: "sleet" },
    57 => { label: "Freezing drizzle", icon_day: "sleet", icon_night: "sleet" },
    61 => { label: "Slight rain", icon_day: "rain", icon_night: "rain" },
    62 => { label: "Moderate rain", icon_day: "rain", icon_night: "rain" },
    63 => { label: "Moderate rain", icon_day: "rain", icon_night: "rain" },
    65 => { label: "Heavy rain", icon_day: "heavy-rain", icon_night: "heavy-rain" },
    66 => { label: "Freezing rain", icon_day: "sleet", icon_night: "sleet" },
    67 => { label: "Freezing rain", icon_day: "sleet", icon_night: "sleet" },
    71 => { label: "Slight snow", icon_day: "snow", icon_night: "snow" },
    73 => { label: "Moderate snow", icon_day: "snow", icon_night: "snow" },
    75 => { label: "Heavy snow", icon_day: "snow", icon_night: "snow" },
    77 => { label: "Snow grains", icon_day: "snow", icon_night: "snow" },
    80 => { label: "Rain showers", icon_day: "rain", icon_night: "rain" },
    81 => { label: "Rain showers", icon_day: "rain", icon_night: "rain" },
    82 => { label: "Violent rain showers", icon_day: "heavy-rain", icon_night: "heavy-rain" },
    85 => { label: "Snow showers", icon_day: "snow", icon_night: "snow" },
    86 => { label: "Heavy snow showers", icon_day: "snow", icon_night: "snow" },
    95 => { label: "Thunderstorm", icon_day: "thunderstorm", icon_night: "thunderstorm" },
    96 => { label: "Thunderstorm with hail", icon_day: "thunderstorm", icon_night: "thunderstorm" },
    99 => { label: "Thunderstorm with hail", icon_day: "thunderstorm", icon_night: "thunderstorm" }
  }.freeze

  class << self
    def current(force_refresh: false)
      if force_refresh
        refresh!
      else
        cached = Rails.cache.read(CACHE_KEY)
        if cached.present?
          # If data is present but older than refresh interval, kick off a refresh or warm it
          cached
        else
          refresh!
        end
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

    def timezone
      ENV["WEATHER_TIMEZONE"].presence || DEFAULT_TIMEZONE
    end

    def forecast_url
      ENV["WEATHER_FORECAST_URL"].presence || "https://weather.gc.ca/en/location/index.html?coords=#{latitude},#{longitude}"
    end

    def degrees_to_cardinal(deg)
      return nil unless deg
      idx = ((deg % 360) / 22.5).round % 16
      CARDINAL_DIRECTIONS[idx]
    end

    def c_to_f(c)
      return nil unless c
      ((c * 9.0 / 5.0) + 32.0).round(1)
    end

    private

    def fetch_from_api
      uri = URI("https://api.open-meteo.com/v1/forecast")
      params = {
        latitude: latitude,
        longitude: longitude,
        current: "temperature_2m,weather_code,is_day,wind_speed_10m,wind_direction_10m",
        daily: "temperature_2m_max,temperature_2m_min",
        timezone: timezone,
        forecast_days: 1
      }
      uri.query = URI.encode_www_form(params)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 3
      http.read_timeout = 4

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "InkbirdServer/1.0 (telemetry-cottage)"

      response = http.request(request)
      return nil unless response.is_a?(Net::HTTPSuccess)

      parse_payload(JSON.parse(response.body))
    end

    def parse_payload(payload)
      curr = payload["current"] || {}
      daily = payload["daily"] || {}

      temp_c = curr["temperature_2m"]&.to_f&.round(1)
      weather_code = curr["weather_code"]&.to_i
      is_day = curr["is_day"] == 1
      wind_speed_kmh = curr["wind_speed_10m"]&.to_f&.round(0)&.to_i
      wind_direction_deg = curr["wind_direction_10m"]&.to_f

      high_c = daily["temperature_2m_max"]&.first&.to_f&.round(1)
      low_c = daily["temperature_2m_min"]&.first&.to_f&.round(1)

      mapping = WMO_CODES[weather_code] || {
        label: "Unknown",
        icon_day: is_day ? "clear-day" : "clear-night",
        icon_night: "clear-night"
      }

      icon_key = is_day ? mapping[:icon_day] : mapping[:icon_night]
      wind_cardinal = degrees_to_cardinal(wind_direction_deg)

      {
        location_name: location_name,
        forecast_url: forecast_url,
        fetched_at: Time.current.iso8601,
        is_day: is_day,
        weather_code: weather_code,
        condition_label: mapping[:label],
        icon_key: icon_key,
        temp_c: temp_c,
        temp_f: c_to_f(temp_c),
        high_c: high_c,
        high_f: c_to_f(high_c),
        low_c: low_c,
        low_f: c_to_f(low_c),
        wind_speed_kmh: wind_speed_kmh,
        wind_direction_deg: wind_direction_deg,
        wind_direction_cardinal: wind_cardinal
      }.with_indifferent_access
    end
  end
end
