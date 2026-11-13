module RevenueProjectionHistoryExportsHelper
  def revenue_projection_history_xlsx_sheets(history, cut_items: [])
    cut = revenue_projection_history_xlsx_cut(cut_items)
    return [revenue_projection_history_xlsx_today(history, cut)] if history.period_type == 'today'

    summary_columns = history.snapshot_period? ? revenue_projection_history_xlsx_summary_columns : revenue_projection_history_xlsx_range_columns
    summary_columns.insert(1, cut)
    return [Export::Sheet.new(name: t('revenue_projection_histories.xlsx.summary'), columns: summary_columns, rows: [])] unless history.any?

    [Export::Sheet.new(name: t('revenue_projection_histories.xlsx.summary'), columns: summary_columns, rows: [history]),
     revenue_projection_history_xlsx_evolution(history),
     revenue_projection_history_xlsx_weeks(history),
     Export::Sheet.new(name: t('revenue_projection_histories.show.days_title'), columns: revenue_projection_history_xlsx_day_columns(history),
                       rows: history.day_rows)].compact
  end

  private

  def revenue_projection_history_xlsx_header(key)
    t(key, scope: 'revenue_projection_histories.xlsx')
  end

  def revenue_projection_history_xlsx_ratio(header)
    xlsx_field(header, :percentage) { |row| row.difference_ratio&.*(100) }
  end

  def revenue_projection_history_xlsx_cut(cut_items)
    text = cut_items.map { |label, value| t('revenue_projection_histories.show.cut_item', label:, value:) }.join(', ')
    text = t('revenue_projection_histories.xlsx.whole_company') if text.empty?

    xlsx_field(revenue_projection_history_xlsx_header(:cut)) { text }
  end

  def revenue_projection_history_xlsx_boolean(value)
    t(value.to_s, scope: 'revenue_projection_histories.xlsx.booleans')
  end

  def revenue_projection_history_xlsx_period
    xlsx_field(revenue_projection_history_xlsx_header(:period)) { |history| revenue_projection_history_period_name(history.period_type, history.period) }
  end

  def revenue_projection_history_xlsx_evolution(history)
    return unless history.snapshot_period?

    Export::Sheet.new(name: t('revenue_projection_histories.xlsx.evolution'), columns: revenue_projection_history_xlsx_evolution_columns(history),
                      rows: history.snapshots)
  end

  def revenue_projection_history_xlsx_weeks(history)
    return if history.week_rows.empty?

    Export::Sheet.new(name: t('revenue_projection_histories.show.weeks_title'), columns: revenue_projection_history_xlsx_week_columns, rows: history.week_rows)
  end

  def revenue_projection_history_xlsx_summary_columns
    [revenue_projection_history_xlsx_period,
     xlsx_field(revenue_projection_history_xlsx_header(:opening_date), :date) { |history| history.opening.taken_on },
     xlsx_field(revenue_projection_history_xlsx_header(:opening), :money) { |history| history.opening.projected_cents },
     xlsx_field(revenue_projection_history_xlsx_header(:latest_date), :date) { |history| history.latest.taken_on },
     xlsx_field(revenue_projection_history_xlsx_header(:latest), :money) { |history| history.latest.projected_cents },
     xlsx_field(revenue_projection_history_xlsx_header(:billed_until), :date, &:last_closed_date),
     xlsx_field(revenue_projection_history_xlsx_header(:billed), :money, &:billed_cents),
     xlsx_field(revenue_projection_history_xlsx_header(:difference), :money, &:difference_cents),
     revenue_projection_history_xlsx_ratio(revenue_projection_history_xlsx_header(:difference_ratio)),
     xlsx_field(revenue_projection_history_xlsx_header(:closed)) { |history| revenue_projection_history_xlsx_boolean(history.closed?) },
     xlsx_field(t('revenue_projection_histories.xlsx.hit_since', tolerance: revenue_projection_history_tolerance), :date, &:hit_since)]
  end

  def revenue_projection_history_xlsx_range_columns
    [revenue_projection_history_xlsx_period,
     xlsx_field(revenue_projection_history_xlsx_header(:billed_until), :date, &:last_closed_date),
     xlsx_field(t('revenue_projection_histories.show.week_forecast'), :money, &:forecast_cents),
     xlsx_field(revenue_projection_history_xlsx_header(:billed), :money, &:billed_cents),
     xlsx_field(revenue_projection_history_xlsx_header(:difference), :money, &:difference_cents),
     revenue_projection_history_xlsx_ratio(revenue_projection_history_xlsx_header(:difference_ratio)),
     xlsx_field(revenue_projection_history_xlsx_header(:closed)) { |history| revenue_projection_history_xlsx_boolean(history.closed?) }]
  end

  def revenue_projection_history_xlsx_evolution_columns(history)
    [xlsx_field(revenue_projection_history_xlsx_header(:taken_on), :date, &:taken_on),
     xlsx_field(revenue_projection_history_xlsx_header(:reference_at), :datetime, &:reference_at),
     xlsx_field(revenue_projection_history_xlsx_header(:realized), :money, &:realized_cents),
     xlsx_field(t(history.period_type, scope: 'revenue_projection_histories.xlsx.projected'), :money, &:projected_cents),
     xlsx_field(revenue_projection_history_xlsx_header(:low), :money, &:low_cents),
     xlsx_field(revenue_projection_history_xlsx_header(:high), :money, &:high_cents),
     xlsx_field(revenue_projection_history_xlsx_header(:reconstructed)) { |snapshot| revenue_projection_history_xlsx_boolean(snapshot.reconstructed) }]
  end

  def revenue_projection_history_xlsx_week_columns
    [xlsx_field(revenue_projection_history_xlsx_header(:week_start), :date) { |row| row.period.first },
     xlsx_field(revenue_projection_history_xlsx_header(:week_end), :date) { |row| row.period.last },
     xlsx_field(t('revenue_projection_histories.show.week_opening'), :money, &:opening_cents),
     xlsx_field(t('revenue_projection_histories.show.week_forecast'), :money, &:forecast_cents),
     xlsx_field(t('revenue_projection_histories.show.billed'), :money, &:billed_cents),
     xlsx_field(t('revenue_projection_histories.show.difference'), :money, &:difference_cents),
     revenue_projection_history_xlsx_ratio(revenue_projection_history_xlsx_header(:difference_ratio)),
     xlsx_field(t('revenue_projection_histories.show.status')) { |row| t(row.closed ? 'closed' : 'in_progress', scope: 'revenue_projection_histories.show') }]
  end

  def revenue_projection_history_xlsx_day_columns(history)
    [xlsx_field(t('revenue_projection_histories.show.date'), :date, &:date),
     xlsx_field(revenue_projection_history_xlsx_header(:day_type)) { |row| RevenueProjection::DailyTotal.human_enum_name(:day_type, row.day_type) },
     xlsx_field(t('revenue_projection_histories.show.forecast'), :money, &:forecast_cents),
     xlsx_field(t('revenue_projection_histories.show.billed'), :money, &:billed_cents),
     xlsx_field(t('revenue_projection_histories.show.difference'), :money, &:difference_cents),
     revenue_projection_history_xlsx_ratio(revenue_projection_history_xlsx_header(:difference_ratio)),
     xlsx_field(t('revenue_projection_histories.show.documents'), :integer, &:documents_count),
     xlsx_field(t(history.period_type, scope: 'revenue_projection_histories.show.projection_morning'), :money, &:projected_cents),
     xlsx_field(revenue_projection_history_xlsx_header(:note)) { |row| row.note&.body },
     xlsx_field(revenue_projection_history_xlsx_header(:note_author)) { |row| row.note&.user&.name }]
  end

  def revenue_projection_history_xlsx_today(today, cut)
    columns = [xlsx_field(t('revenue_projection_histories.show.date'), :date, &:today),
               cut,
               xlsx_field(revenue_projection_history_xlsx_header(:day_type)) { |row| RevenueProjection::DailyTotal.human_enum_name(:day_type, row.day_type) },
               xlsx_field(t('revenue_projection_histories.today.forecast'), :money, &:forecast_cents),
               xlsx_field(t('revenue_projection_histories.today.billed'), :money, &:billed_cents),
               xlsx_field(revenue_projection_history_xlsx_header(:difference), :money, &:difference_cents),
               revenue_projection_history_xlsx_ratio(revenue_projection_history_xlsx_header(:difference_ratio)),
               xlsx_field(t('revenue_projection_histories.show.documents'), :integer, &:documents_count),
               xlsx_field(t('revenue_projection_histories.today.month_projection'), :money) { |row| row.month_snapshot&.projected_cents },
               xlsx_field(t('revenue_projection_histories.today.week_projection'), :money) { |row| row.week_snapshot&.projected_cents },
               xlsx_field(revenue_projection_history_xlsx_header(:reference_at), :datetime, &:last_synced_at)]

    Export::Sheet.new(name: t('revenue_projection_histories.xlsx.summary'), columns:, rows: today.any? ? [today] : [])
  end
end
