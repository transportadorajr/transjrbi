module RevenueProjectionsHelper
  PROJECTED_ORANGE = '#f97316'.freeze
  PROJECTION_SERIES = [
    { color: ChartsHelper::BRAND_BLUE, dataset: { borderColor: ChartsHelper::BRAND_BLUE, backgroundColor: ChartsHelper::BRAND_BLUE } },
    { color: PROJECTED_ORANGE, dataset: { borderColor: PROJECTED_ORANGE, backgroundColor: PROJECTED_ORANGE, borderDash: [6, 4] } },
  ].freeze
  COMPACT_LABEL_ALIGNS = [40, 200].freeze
  COMPACT_POINT_RADIUS = 4
  COMPACT_DATE_TICKS = 6
  COMPACT_VALUE_TICKS = 4

  def revenue_projection_periods
    Dashboard::RevenueProjection::PERIOD_TYPES
  end

  def revenue_projection_period_label(period_type)
    t(period_type, scope: 'revenue_projections.periods')
  end

  def revenue_projection_period_link_class(period_type, selected)
    "btn btn-sm #{period_type == selected ? 'btn-primary' : 'btn-outline-secondary'}"
  end

  def revenue_projection_chart_title(projection)
    t(projection.period_type, scope: 'revenue_projections.show.chart_title')
  end

  def revenue_projection_last_sync_label(last_synced_at)
    return t('revenue_projections.show.never_synced') unless last_synced_at

    t('revenue_projections.show.last_sync', time: l(last_synced_at, format: :date_time))
  end

  def revenue_projection_title(projection)
    revenue_projection_period_name(projection.period_type, projection.period.first, projection.period.last)
  end

  def revenue_projection_period_name(period_type, period_start, period_end)
    return t('revenue_projections.show.month_title', month: l(period_start, format: :month_name)) if period_type.to_s == 'month'

    t('revenue_projections.show.week_title', start: l(period_start, format: :chart_week), finish: l(period_end, format: :chart_week))
  end

  def revenue_projection_day_label(day_type, wday)
    return t('date.day_names')[wday].capitalize if day_type.to_sym == :regular

    t(day_type, scope: 'revenue_projections.memory.day_types')
  end

  def revenue_projection_factor_label(factor_type, wday)
    return t('revenue_projections.memory.weekday_bias', day: t('date.day_names')[wday]) if factor_type.to_sym == :weekday_bias

    t(factor_type, scope: 'revenue_projections.memory.day_types')
  end

  def revenue_projection_factor_value(value)
    t('revenue_projections.memory.factor_value', value: number_to_percentage(value * 100, precision: 0))
  end

  def revenue_projection_factor_status(row)
    return status_badge(t('revenue_projections.memory.learned'), kind: :success) if row.learned

    status_badge(t('revenue_projections.memory.default'), kind: :secondary)
  end

  def revenue_projection_error(ratio)
    return t('revenue_projections.memory.missing') unless ratio

    number_to_percentage(ratio * 100, precision: 1)
  end

  def revenue_projection_bias(ratio)
    return t('revenue_projections.memory.missing') unless ratio
    return t('revenue_projections.memory.bias_none') if ratio.round(3).zero?

    t(ratio.negative? ? 'revenue_projections.memory.bias_below' : 'revenue_projections.memory.bias_above',
      value: number_to_percentage(ratio.abs * 100, precision: 1))
  end

  def revenue_projection_signed_error(ratio)
    return t('revenue_projections.memory.missing') unless ratio

    "#{'+' unless ratio.negative?}#{number_to_percentage(ratio * 100, precision: 1)}"
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

  def revenue_projection_charts(projection)
    safe_join([
                tag.div(revenue_projection_chart(projection), class: 'd-none d-md-block'),
                tag.div(revenue_projection_compact_chart(projection), class: 'd-md-none'),
              ])
  end

  def revenue_projection_chart(projection)
    line_chart(projection.chart_data.zip(PROJECTION_SERIES).map { |serie, style| serie.merge(style) },
               height: ChartsHelper::CHART_HEIGHT, legend: 'bottom', discrete: true, points: false, **chart_money_options,
               library: chart_bar_library(:x))
  end

  def revenue_projection_compact_chart(projection)
    line_chart(revenue_projection_compact_series(projection), height: ChartsHelper::CHART_HEIGHT, legend: 'bottom', discrete: true,
                                                              points: false, **chart_money_options, round: 0, zeros: false,
                                                              library: revenue_projection_compact_library)
  end

  def revenue_projection_compact_series(projection)
    labels_count = projection.period.count
    last_indexes = [projection.chart_data.first[:data].size - 1, labels_count - 1]

    projection.chart_data.zip(PROJECTION_SERIES, COMPACT_LABEL_ALIGNS, last_indexes).map do |serie, style, align, last_index|
      serie.merge(style).deep_merge(dataset: revenue_projection_point_dataset(labels_count, last_index, align))
    end
  end

  private

  def revenue_projection_point_dataset(labels_count, point_index, align)
    last_point = Array.new(labels_count) { |index| index == point_index }

    {
      pointRadius: last_point.map { it ? COMPACT_POINT_RADIUS : 0 },
      datalabels: { display: last_point, align:, offset: 6, clamp: true, font: { size: 11, weight: 700 } },
    }
  end

  def revenue_projection_compact_library
    chart_bar_library(:x).deep_merge(
      layout: { padding: { top: 16, right: 8 } },
      scales: {
        x: { ticks: { autoSkip: true, maxTicksLimit: COMPACT_DATE_TICKS, maxRotation: 0 } },
        y: { ticks: { maxTicksLimit: COMPACT_VALUE_TICKS } },
      },
    )
  end

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
