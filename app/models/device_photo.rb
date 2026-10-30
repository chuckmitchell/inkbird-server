class DevicePhoto < ApplicationRecord
  belongs_to :device

  validates :recorded_at, presence: true
  validates :recorded_at, uniqueness: { scope: [ :device_id, :lens ] }
  validates :lens, presence: true
  validates :file_path, presence: true
  validates :byte_size, presence: true, numericality: { only_integer: true, greater_than: 0 }

  scope :chronological, -> { order(recorded_at: :asc) }
  scope :recent_first, -> { order(recorded_at: :desc) }
  scope :older_than, ->(time) { where(recorded_at: ...time) }

  after_destroy :delete_file_from_disk

  def self.storage_root
    if Rails.env.test?
      Rails.root.join("tmp/storage/photos")
    else
      Rails.root.join("storage/photos")
    end
  end

  def self.build_relative_path(tuya_device_id:, recorded_at:, lens:)
    safe_device = tuya_device_id.to_s.gsub(/[^a-zA-Z0-9_-]/, "_")
    safe_lens = lens.to_s.presence&.gsub(/[^a-zA-Z0-9_-]/, "_") || "REAR_WIDE"
    date_folder = recorded_at.utc.strftime("%Y-%m-%d")
    timestamp_slug = recorded_at.utc.strftime("%Y%m%dT%H%M%SZ")

    File.join(safe_device, date_folder, "#{timestamp_slug}_#{safe_lens}.jpg")
  end

  def absolute_file_path
    self.class.storage_root.join(file_path)
  end

  def file_exists?
    file_path.present? && File.exist?(absolute_file_path)
  end

  def write_image_bytes!(bytes)
    full_path = absolute_file_path
    FileUtils.mkdir_p(File.dirname(full_path))
    File.binwrite(full_path, bytes)
    self.byte_size = bytes.bytesize
  end

  private

  def delete_file_from_disk
    return unless file_exists?

    FileUtils.rm_f(absolute_file_path)
  end
end
