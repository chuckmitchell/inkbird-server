class PhotosController < ApplicationController
  DAYS_PER_PAGE = 3

  before_action :set_device, only: [ :index ]

  def index
    if @device.nil?
      redirect_to root_path, alert: "Device not found."
      return
    end

    @page = [ params[:page].to_i, 1 ].max
    distinct_dates = @device.device_photos
                            .select(Arel.sql("DATE(recorded_at) as photo_date"))
                            .distinct
                            .order(Arel.sql("DATE(recorded_at) DESC"))
                            .pluck(Arel.sql("DATE(recorded_at)"))

    offset = (@page - 1) * DAYS_PER_PAGE
    @paged_dates = distinct_dates.slice(offset, DAYS_PER_PAGE) || []
    @next_page = distinct_dates.size > offset + DAYS_PER_PAGE ? @page + 1 : nil

    if @paged_dates.any?
      @photos = @device.device_photos
                       .where(Arel.sql("DATE(recorded_at) IN (?)"), @paged_dates)
                       .recent_first
      @grouped_photos = @photos.group_by { |p| p.recorded_at.utc.to_date }
    else
      @grouped_photos = {}
    end
  end

  def show
    photo = DevicePhoto.find_by(id: params[:id])
    if photo.nil? || !photo.file_exists?
      head :not_found
      return
    end

    expires_in 30.days, public: true
    send_file photo.absolute_file_path,
      type: "image/jpeg",
      disposition: "inline",
      filename: File.basename(photo.file_path)
  end

  private

  def set_device
    @device = Device.find_by(tuya_device_id: params[:device_id]) || Device.find_by(id: params[:device_id])
  end
end
