module Api
  module V1
    class TelemetryController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_ingest_token!

      def create
        device_id = params[:device_id].to_s.strip
        timestamp_str = params[:timestamp_utc].to_s.strip

        if device_id.blank? || timestamp_str.blank?
          return render json: { error: "device_id and timestamp_utc are required" }, status: :unprocessable_entity
        end

        begin
          recorded_at = Time.iso8601(timestamp_str).utc
        rescue ArgumentError
          return render json: { error: "timestamp_utc must be a valid ISO-8601 timestamp" }, status: :unprocessable_entity
        end

        device = Device.find_or_create_by!(tuya_device_id: device_id)
        reading = device.telemetry_readings.find_or_initialize_by(recorded_at: recorded_at)
        newly_created = reading.new_record?

        reading.assign_attributes(
          unit: params[:unit].presence || "C",
          current_temp_c: params[:current_temp_c],
          current_temp_f: params[:current_temp_f],
          target_temp_c: params[:target_temp_c],
          relay_state: params[:relay_state].presence || "unknown",
          compressor_delay_min: params[:compressor_delay_min],
          high_alarm_limit: params[:high_alarm_limit],
          low_alarm_limit: params[:low_alarm_limit],
          alarms: normalize_json_object(params[:alarms]),
          raw_dps: normalize_json_object(params[:raw_dps])
        )

        ActiveRecord::Base.transaction do
          reading.save!
          device.refresh_cached_state!(reading)
        end

        render json: { status: "ok", reading_id: reading.id }, status: (newly_created ? :created : :ok)
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      def authenticate_ingest_token!
        expected_token = ENV["INGEST_BEARER_TOKEN"].to_s

        if expected_token.blank?
          render json: { error: "Server INGEST_BEARER_TOKEN is not configured" }, status: :internal_server_error
          return
        end

        authenticated = authenticate_with_http_token do |token, _options|
          ActiveSupport::SecurityUtils.secure_compare(token.to_s, expected_token)
        end

        return if authenticated

        render json: { error: "Unauthorized" }, status: :unauthorized
      end

      def normalize_json_object(value)
        case value
        when ActionController::Parameters
          value.to_unsafe_h
        when Hash
          value
        else
          {}
        end
      end
    end
  end
end
