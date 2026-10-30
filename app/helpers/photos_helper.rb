module PhotosHelper
  def photo_date_heading(date)
    return "" if date.nil?

    today = Time.current.in_time_zone(ApplicationHelper::ATLANTIC_TIME_ZONE).to_date
    if date == today
      "Today"
    elsif date == today - 1.day
      "Yesterday"
    else
      date.strftime("%A, %B %-d, %Y")
    end
  end
end
