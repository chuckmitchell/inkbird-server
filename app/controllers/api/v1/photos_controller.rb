require "base64"

module Api
  module V1
    class PhotosController < BaseController
      JPEG_MAGIC_BYTES = "\xFF\xD8\xFF".b.freeze
      MAX_IMAGE_BYTES = 5.megabytes
      MAX_BASE64_BYTES = ((MAX_IMAGE_BYTES * 4) / 3) + 1024

      def create
        device_id = params[:device_id].to_s.strip
        timestamp_str = params[:timestamp_utc].to_s.strip
        image_base64 = params[:image_base64].to_s.strip

        if device_id.blank? || timestamp_str.blank? || image_base64.blank?
          return render json: { error: "device_id, timestamp_utc, and image_base64 are required" }, status: :unprocessable_entity
        end

        if image_base64.bytesize > MAX_BASE64_BYTES
          return render json: { error: "image_base64 exceeds maximum allowed size of 5 MB" }, status: :unprocessable_entity
        end

        begin
          recorded_at = Time.iso8601(timestamp_str).utc
        rescue ArgumentError
          return render json: { error: "timestamp_utc must be a valid ISO-8601 timestamp" }, status: :unprocessable_entity
        end

        image_bytes = decode_jpeg_bytes(image_base64)
        if image_bytes.nil?
          return render json: { error: "image_base64 must be a valid Base64-encoded JPEG image" }, status: :unprocessable_entity
        end

        next_photo_at = nil
        if params[:next_photo_utc].present?
          begin
            next_photo_at = Time.iso8601(params[:next_photo_utc].to_s.strip).utc
          rescue ArgumentError
            return render json: { error: "next_photo_utc must be a valid ISO-8601 timestamp" }, status: :unprocessable_entity
          end
        end

        lens = params[:lens].to_s.strip.presence || "REAR_WIDE"
        device = Device.find_or_create_by!(tuya_device_id: device_id)
        photo = device.device_photos.find_or_initialize_by(recorded_at: recorded_at, lens: lens)
        newly_created = photo.new_record?

        relative_path = DevicePhoto.build_relative_path(
          tuya_device_id: device.tuya_device_id,
          recorded_at: recorded_at,
          lens: lens
        )

        photo.assign_attributes(
          next_photo_at: next_photo_at,
          width: params[:width].presence&.to_i,
          height: params[:height].presence&.to_i,
          current_temp_c: params[:current_temp_c].presence&.to_f,
          file_path: relative_path
        )

        ActiveRecord::Base.transaction do
          photo.write_image_bytes!(image_bytes)
          photo.save!
          device.record_photo_seen!(recorded_at, current_temp_c: photo.current_temp_c, next_photo_at: photo.next_photo_at)
        end

        render json: { status: "ok", photo_id: photo.id }, status: (newly_created ? :created : :ok)
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      def decode_jpeg_bytes(raw_base64)
        cleaned = raw_base64.sub(/\Adata:image\/[a-zA-Z0-9.+-]+;base64,/, "").gsub(/\s+/, "")
        return nil if cleaned.empty? || cleaned.bytesize > MAX_BASE64_BYTES

        decoded = Base64.strict_decode64(cleaned).b
        return nil if decoded.bytesize > MAX_IMAGE_BYTES
        return nil unless decoded.start_with?(JPEG_MAGIC_BYTES)

        decoded
      rescue ArgumentError
        nil
      end
    end
  end
end
