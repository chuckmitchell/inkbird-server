module ApplicationHelper
  extend self

  ATLANTIC_TIME_ZONE = "Atlantic Time (Canada)".freeze

  # Full friendly timestamp in Atlantic time (ADT or AST), locked to the time zone when recorded.
  # Example: "Friday October 30, 2026 - 11:50am (ADT)"
  def friendly_timestamp(time)
    return "" if time.blank?

    parsed = time.is_a?(String) ? Time.zone.parse(time) : time
    parsed.in_time_zone(ATLANTIC_TIME_ZONE).strftime("%A %B %-d, %Y - %-l:%M%P (%Z)")
  end
  alias_method :format_timestamp, :friendly_timestamp
  alias_method :atlantic_timestamp, :friendly_timestamp
  alias_method :friendly_date_time, :friendly_timestamp

  # Short friendly timestamp for small spaces in Atlantic time (ADT or AST), locked to the time zone when recorded.
  # Example: "Fri, Oct 30, 2026 - 11:50am"
  def friendly_timestamp_short(time)
    return "" if time.blank?

    parsed = time.is_a?(String) ? Time.zone.parse(time) : time
    parsed.in_time_zone(ATLANTIC_TIME_ZONE).strftime("%a, %b %-d, %Y - %-l:%M%P")
  end
  alias_method :format_timestamp_short, :friendly_timestamp_short
  alias_method :short_timestamp, :friendly_timestamp_short
  alias_method :atlantic_timestamp_short, :friendly_timestamp_short
  alias_method :friendly_date_time_short, :friendly_timestamp_short

  # Relative description for next expected poll time (e.g., "in 56 minutes", "5 minutes overdue").
  def relative_poll_time(time)
    return "" if time.blank?

    target = time.is_a?(String) ? Time.zone.parse(time) : time
    now = Time.current

    if target >= now
      diff_seconds = (target - now).to_i
      if diff_seconds < 60
        "in less than a minute"
      elsif diff_seconds < 3600
        mins = (diff_seconds / 60.0).round
        "in #{mins} #{'minute'.pluralize(mins)}"
      else
        "in #{time_ago_in_words(target)}"
      end
    else
      diff_seconds = (now - target).to_i
      if diff_seconds < 60
        "moments overdue"
      elsif diff_seconds < 3600
        mins = (diff_seconds / 60.0).round
        "#{mins} #{'minute'.pluralize(mins)} overdue"
      else
        "#{time_ago_in_words(target)} overdue"
      end
    end
  end
end
