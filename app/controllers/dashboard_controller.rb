class DashboardController < ApplicationController
  VALID_RANGES = {
    "24h" => { duration: 24.hours, label: "Last 24 Hours", bucket_label: "5-minute averages" },
    "7d"  => { duration: 7.days,   label: "Last 7 Days",   bucket_label: "Hourly averages" },
    "30d" => { duration: 30.days,  label: "Last 30 Days",  bucket_label: "6-hour averages" }
  }.freeze

  def show
    @devices = Device.order(last_seen_at: :desc, created_at: :asc)
    @device = if params[:device_id].present?
      @devices.find_by(tuya_device_id: params[:device_id]) || @devices.first
    else
      @devices.first
    end

    @range = VALID_RANGES.key?(params[:range]) ? params[:range] : "24h"
    @range_meta = VALID_RANGES[@range]

    if @device
      window_start = @range_meta[:duration].ago
      readings_in_window = @device.telemetry_readings.since(window_start)

      @chart_data = build_chart_data(readings_in_window, @range)
      @latest_reading = @device.telemetry_readings.recent_first.first
      @recent_readings = @device.telemetry_readings.recent_first.limit(12)
      @latest_photo = @device.device_photos.recent_first.first
      @recent_photos = @device.device_photos.recent_first.offset(1).limit(6)

      @stats = {
        min_c: readings_in_window.minimum(:current_temp_c)&.round(1),
        max_c: readings_in_window.maximum(:current_temp_c)&.round(1),
        avg_c: readings_in_window.average(:current_temp_c)&.round(1),
        count: readings_in_window.count
      }
    else
      @chart_data = {}
      @latest_reading = nil
      @recent_readings = []
      @latest_photo = nil
      @recent_photos = []
      @stats = { min_c: nil, max_c: nil, avg_c: nil, count: 0 }
    end
  end

  private

  def build_chart_data(scope, range)
    grouped = case range
    when "24h"
      scope.group_by_minute(:recorded_at, n: 5, series: false).average(:current_temp_c)
    when "7d"
      scope.group_by_hour(:recorded_at, series: false).average(:current_temp_c)
    when "30d"
      scope.group_by_hour(:recorded_at, n: 6, series: false).average(:current_temp_c)
    end

    grouped.transform_values { |val| val&.round(1) }
  end
end
