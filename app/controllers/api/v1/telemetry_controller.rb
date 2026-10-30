module Api
  module V1
    class TelemetryController < BaseController
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

        next_poll_at = nil
        if params[:next_poll_utc].present?
          begin
            next_poll_at = Time.iso8601(params[:next_poll_utc].to_s.strip).utc
          rescue ArgumentError
            return render json: { error: "next_poll_utc must be a valid ISO-8601 timestamp" }, status: :unprocessable_entity
          end
        end

        next_photo_at = nil
        if params[:next_photo_utc].present?
          begin
            next_photo_at = Time.iso8601(params[:next_photo_utc].to_s.strip).utc
          rescue ArgumentError
            return render json: { error: "next_photo_utc must be a valid ISO-8601 timestamp" }, status: :unprocessable_entity
          end
        end

        device = Device.find_or_create_by!(tuya_device_id: device_id)
        reading = device.telemetry_readings.find_or_initialize_by(recorded_at: recorded_at)
        newly_created = reading.new_record?

        reading.assign_attributes(
          next_poll_at: next_poll_at,
          next_photo_at: next_photo_at,
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

      MAX_JSON_KEYS = 50
      MAX_JSON_STRING_BYTES = 256

      def normalize_json_object(value)
        raw_hash = case value
        when ActionController::Parameters
          value.to_unsafe_h
        when Hash
          value
        else
          return {}
        end

        sanitized = {}
        raw_hash.each do |k, v|
          break if sanitized.size >= MAX_JSON_KEYS

          key = k.to_s.slice(0, 64)
          next if key.empty?

          sanitized[key] = case v
          when Numeric, TrueClass, FalseClass, NilClass
            v
          when String
            v.byteslice(0, MAX_JSON_STRING_BYTES)
          else
            v.to_s.byteslice(0, MAX_JSON_STRING_BYTES)
          end
        end
        sanitized
      end
    end
  end
end
