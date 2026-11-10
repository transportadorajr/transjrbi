module TripDurationsHelper
  def trip_duration(duration)
    return t('tax.blank') if duration.nil?
    return t('trip_durations.less_than_an_hour') if duration.hours.zero?

    parts = []
    parts << t('trip_durations.days', count: duration.days) if duration.days.positive?
    parts << t('trip_durations.hours', count: duration.remaining_hours) if duration.remaining_hours.positive?

    parts.to_sentence
  end

  def trip_duration_in_progress(elapsed)
    content_tag(:span, t('trip_durations.in_progress', duration: trip_duration(elapsed)), class: 'trip-duration-in-progress text-body-secondary fst-italic')
  end

  def trip_durations_cards(durations)
    render 'shared/trip_durations', durations:
  end

  def trip_durations_excluded_note(durations)
    return if durations.excluded_count.zero?

    content_tag(:p, t('trip_durations.excluded', count: durations.excluded_count), class: 'small text-body-secondary mb-0 mt-2')
  end
end
