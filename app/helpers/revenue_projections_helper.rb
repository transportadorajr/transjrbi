module RevenueProjectionsHelper
  PROJECTED_ORANGE = '#f97316'.freeze
  PROJECTION_SERIES = [
    { color: ChartsHelper::BRAND_BLUE, dataset: { borderColor: ChartsHelper::BRAND_BLUE, backgroundColor: ChartsHelper::BRAND_BLUE } },
    { color: PROJECTED_ORANGE, dataset: { borderColor: PROJECTED_ORANGE, backgroundColor: PROJECTED_ORANGE, borderDash: [6, 4] } },
  ].freeze

  def revenue_projection_last_sync_label(last_synced_at)
    return t('revenue_projections.show.never_synced') unless last_synced_at

    t('revenue_projections.show.last_sync', time: l(last_synced_at, format: :date_time))
  end

  def revenue_projection_title(projection)
    return t('revenue_projections.show.month_title', month: l(projection.period.first, format: :month_name)) if projection.period_type == :month

    t('revenue_projections.show.week_title', start: l(projection.period.first, format: :chart_week), finish: l(projection.period.last, format: :chart_week))
  end

  def revenue_projection_deadline_label(projection)
    t('revenue_projections.show.projected_until', time: l(projection.period.last.end_of_day, format: :date_time))
  end

  def revenue_projection_realized_label(projection)
    t('revenue_projections.show.realized_until', time: l(projection.reference_at, format: :date_time))
  end

  def revenue_projection_range(projection)
    t('revenue_projections.show.range_value', low: tax_money(projection.low), high: tax_money(projection.high))
  end

  def revenue_projection_alerts(projection)
    safe_join([revenue_projection_holidays_alert(projection), revenue_projection_history_alert(projection)].compact)
  end

  def revenue_projection_chart(projection)
    line_chart(projection.chart_data.zip(PROJECTION_SERIES).map { |serie, style| serie.merge(style) },
               height: ChartsHelper::CHART_HEIGHT, legend: 'bottom', discrete: true, points: false, **chart_money_options,
               library: chart_bar_library(:x))
  end

  private

  def revenue_projection_holidays_alert(projection)
    holidays = projection.upcoming_holidays
    return if holidays.empty?

    names = holidays.map { |holiday| t('revenue_projections.show.holiday', date: l(holiday.date, format: :chart_week), name: holiday.name) }
    tag.p(t('revenue_projections.show.holidays_alert', holidays: names.to_sentence), class: 'small text-warning-emphasis mb-0 mt-3')
  end

  def revenue_projection_history_alert(projection)
    return if projection.history?

    tag.p(t('revenue_projections.show.no_history'), class: 'small text-danger mb-0 mt-3')
  end
end
