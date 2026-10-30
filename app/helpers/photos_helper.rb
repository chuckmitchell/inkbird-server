module PhotosHelper
  def photo_date_heading(date)
    return "" if date.nil?

    today = Time.current.utc.to_date
    if date == today
      "Today"
    elsif date == today - 1.day
      "Yesterday"
    else
      date.strftime("%A, %B %-d, %Y")
    end
  end
end
