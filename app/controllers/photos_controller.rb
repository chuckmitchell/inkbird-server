class PhotosController < ApplicationController
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
end
