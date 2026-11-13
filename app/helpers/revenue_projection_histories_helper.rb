module RevenueProjectionHistoriesHelper
  HISTORY_LOW_HIGH_GRAY = '#cbd5e1'.freeze
  HISTORY_SERIES = [
    { color: RevenueProjectionsHelper::PROJECTED_ORANGE,
      dataset: { borderColor: RevenueProjectionsHelper::PROJECTED_ORANGE, backgroundColor: RevenueProjectionsHelper::PROJECTED_ORANGE } },
    { color: HISTORY_LOW_HIGH_GRAY, dataset: { borderColor: HISTORY_LOW_HIGH_GRAY, backgroundColor: HISTORY_LOW_HIGH_GRAY, borderDash: [4, 4], borderWidth: 1 } },
    { color: HISTORY_LOW_HIGH_GRAY, dataset: { borderColor: HISTORY_LOW_HIGH_GRAY, backgroundColor: HISTORY_LOW_HIGH_GRAY, borderDash: [4, 4], borderWidth: 1 } },
    { color: ChartsHelper::BRAND_BLUE, dataset: { borderColor: ChartsHelper::BRAND_BLUE, backgroundColor: ChartsHelper::BRAND_BLUE } },
    { color: ChartsHelper::BRAND_BLUE, dataset: { borderColor: ChartsHelper::BRAND_BLUE, backgroundColor: ChartsHelper::BRAND_BLUE, borderDash: [6, 4] } },
  ].freeze
  HISTORY_DATE_TICKS = 8
  HISTORY_CARD_COLUMNS = 'col-12 col-md-6 col-xxl-3'.freeze

  def revenue_projection_history_body(history)
    return render('shared/no_content') unless history.any?

    render 'revenue_projection_histories/content', history:
  end

  def revenue_projection_history_month_title(history)
    l(history.month, format: :month_name).capitalize
  end

  def revenue_projection_history_month_link(month, direction)
    label = direction == :previous ? t('revenue_projection_histories.show.previous_month') : t('revenue_projection_histories.show.next_month')
    icon_name = direction == :previous ? :'chevron-left' : :'chevron-right'
    return tag.span(icon(icon_name), class: 'btn btn-sm btn-outline-secondary disabled', aria: { label:, disabled: true }) unless month

    link_to icon(icon_name), revenue_projection_history_path(month: Dashboard::RevenueProjectionHistory.month_param(month)),
            class: 'btn btn-sm btn-outline-secondary', title: label, aria: { label: }
  end

  def revenue_projection_history_cards(history)
    safe_join([
                counter_card(:dark, revenue_projection_history_opening_label(history), tax_money(Money.from_cents(history.opening.projected_cents)),
                             col_class: HISTORY_CARD_COLUMNS),
                counter_card(:warning, revenue_projection_history_latest_label(history), tax_money(Money.from_cents(history.latest.projected_cents)),
                             col_class: HISTORY_CARD_COLUMNS),
                counter_card(:primary, revenue_projection_history_billed_label(history), tax_money(Money.from_cents(history.billed_cents)),
                             col_class: HISTORY_CARD_COLUMNS),
                counter_card(revenue_projection_history_difference_kind(history.difference_cents), revenue_projection_history_difference_label(history),
                             revenue_projection_history_difference(history.difference_cents, history.difference_ratio),
                             col_class: HISTORY_CARD_COLUMNS),
              ])
  end

  def revenue_projection_history_notes(history)
    notes = [revenue_projection_history_hit_note(history), revenue_projection_history_reconstructed_note(history)].compact
    safe_join(notes.map { tag.p(it, class: 'small text-muted mb-1') })
  end

  def revenue_projection_history_chart(history)
    line_chart(history.chart_data.zip(HISTORY_SERIES).map { |serie, style| serie.merge(style) },
               height: ChartsHelper::CHART_HEIGHT, legend: 'bottom', discrete: true, points: false, **chart_money_options,
               library: chart_bar_library(:x).deep_merge(scales: { x: { ticks: { autoSkip: true, maxTicksLimit: HISTORY_DATE_TICKS, maxRotation: 0 } } }))
  end

  def revenue_projection_history_header(key)
    safe_join([tag.span(t("#{key}_short", scope: 'revenue_projection_histories.show'), class: 'd-md-none'),
               tag.span(t(key, scope: 'revenue_projection_histories.show'), class: 'd-none d-md-inline')])
  end

  def revenue_projection_history_week_label(row)
    t('revenue_projection_histories.show.week_period', start: l(row.period.first, format: :chart_week), finish: l(row.period.last, format: :chart_week))
  end

  def revenue_projection_history_week_status(row)
    return status_badge(t('revenue_projection_histories.show.closed'), kind: :success) if row.closed

    status_badge(t('revenue_projection_histories.show.in_progress'), kind: :warning)
  end

  def revenue_projection_history_day_label(row)
    t('revenue_projection_histories.show.day', date: l(row.date, format: :chart_week), weekday: t('date.abbr_day_names')[row.date.wday])
  end

  def revenue_projection_history_day_type(row)
    return if row.day_type.to_sym == :regular

    tag.span(RevenueProjection::DailyTotal.human_enum_name(:day_type, row.day_type), class: 'd-block small text-warning-emphasis')
  end

  def revenue_projection_history_money(cents)
    return t('revenue_projection_histories.show.missing') unless cents

    tax_money(Money.from_cents(cents))
  end

  def revenue_projection_history_difference(cents, ratio)
    return t('revenue_projection_histories.show.missing') unless cents

    value = "#{'+' unless cents.negative?}#{tax_money(Money.from_cents(cents))}"
    return value unless ratio

    t('revenue_projection_histories.show.difference_value', value:, ratio: revenue_projection_history_signed_ratio(ratio))
  end

  def revenue_projection_history_signed_ratio(ratio)
    "#{'+' unless ratio.negative?}#{number_to_percentage(ratio * 100, precision: 1)}"
  end

  def revenue_projection_history_compact_ratio(row)
    return unless row.difference_ratio

    tag.span(revenue_projection_history_signed_ratio(row.difference_ratio),
             class: ['d-block small d-md-none', revenue_projection_history_difference_class(row.difference_cents)])
  end

  def revenue_projection_history_difference_class(cents)
    return 'text-muted' unless cents

    cents.negative? ? 'text-danger' : 'text-success'
  end

  def revenue_projection_history_export_button(history)
    xlsx_export_button if history.any?
  end

  def revenue_projection_history_xlsx_sheets(history)
    return [Export::Sheet.new(name: t('revenue_projection_histories.xlsx.summary'), columns: revenue_projection_history_xlsx_summary_columns, rows: [])] unless history.any?

    [Export::Sheet.new(name: t('revenue_projection_histories.xlsx.summary'), columns: revenue_projection_history_xlsx_summary_columns, rows: [history]),
     Export::Sheet.new(name: t('revenue_projection_histories.xlsx.evolution'), columns: revenue_projection_history_xlsx_evolution_columns,
                       rows: history.snapshots),
     Export::Sheet.new(name: t('revenue_projection_histories.show.weeks_title'), columns: revenue_projection_history_xlsx_week_columns,
                       rows: history.week_rows),
     Export::Sheet.new(name: t('revenue_projection_histories.show.days_title'), columns: revenue_projection_history_xlsx_day_columns,
                       rows: history.day_rows)]
  end

  private

  def revenue_projection_history_xlsx_header(key)
    t(key, scope: 'revenue_projection_histories.xlsx')
  end

  def revenue_projection_history_xlsx_ratio(header)
    xlsx_field(header, :percentage) { |row| row.difference_ratio&.*(100) }
  end

  def revenue_projection_history_xlsx_summary_columns
    [xlsx_field(revenue_projection_history_xlsx_header(:month)) { |history| revenue_projection_history_month_title(history) },
     xlsx_field(revenue_projection_history_xlsx_header(:opening_date), :date) { |history| history.opening.taken_on },
     xlsx_field(revenue_projection_history_xlsx_header(:opening), :money) { |history| history.opening.projected_cents },
     xlsx_field(revenue_projection_history_xlsx_header(:latest_date), :date) { |history| history.latest.taken_on },
     xlsx_field(revenue_projection_history_xlsx_header(:latest), :money) { |history| history.latest.projected_cents },
     xlsx_field(revenue_projection_history_xlsx_header(:billed_until), :date, &:last_closed_date),
     xlsx_field(revenue_projection_history_xlsx_header(:billed), :money, &:billed_cents),
     xlsx_field(revenue_projection_history_xlsx_header(:difference), :money, &:difference_cents),
     revenue_projection_history_xlsx_ratio(revenue_projection_history_xlsx_header(:difference_ratio)),
     xlsx_field(revenue_projection_history_xlsx_header(:closed)) { |history| t(history.closed?.to_s, scope: 'revenue_projection_histories.xlsx.booleans') },
     xlsx_field(t('revenue_projection_histories.xlsx.hit_since', tolerance: revenue_projection_history_tolerance), :date, &:hit_since)]
  end

  def revenue_projection_history_xlsx_evolution_columns
    [xlsx_field(revenue_projection_history_xlsx_header(:taken_on), :date, &:taken_on),
     xlsx_field(revenue_projection_history_xlsx_header(:reference_at), :datetime, &:reference_at),
     xlsx_field(revenue_projection_history_xlsx_header(:realized), :money, &:realized_cents),
     xlsx_field(revenue_projection_history_xlsx_header(:projected), :money, &:projected_cents),
     xlsx_field(revenue_projection_history_xlsx_header(:low), :money, &:low_cents),
     xlsx_field(revenue_projection_history_xlsx_header(:high), :money, &:high_cents),
     xlsx_field(revenue_projection_history_xlsx_header(:reconstructed)) { |snapshot| t(snapshot.reconstructed.to_s, scope: 'revenue_projection_histories.xlsx.booleans') }]
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

  def revenue_projection_history_xlsx_day_columns
    [xlsx_field(t('revenue_projection_histories.show.date'), :date, &:date),
     xlsx_field(revenue_projection_history_xlsx_header(:day_type)) { |row| RevenueProjection::DailyTotal.human_enum_name(:day_type, row.day_type) },
     xlsx_field(t('revenue_projection_histories.show.forecast'), :money, &:forecast_cents),
     xlsx_field(t('revenue_projection_histories.show.billed'), :money, &:billed_cents),
     xlsx_field(t('revenue_projection_histories.show.difference'), :money, &:difference_cents),
     revenue_projection_history_xlsx_ratio(revenue_projection_history_xlsx_header(:difference_ratio)),
     xlsx_field(t('revenue_projection_histories.show.documents'), :integer, &:documents_count),
     xlsx_field(t('revenue_projection_histories.show.month_projection'), :money, &:month_projected_cents)]
  end

  def revenue_projection_history_opening_label(history)
    t('revenue_projection_histories.show.opening', date: l(history.opening.taken_on, format: :chart_week))
  end

  def revenue_projection_history_latest_label(history)
    key = history.closed? ? 'final_projection' : 'latest_projection'
    t(key, scope: 'revenue_projection_histories.show', date: l(history.latest.taken_on, format: :chart_week))
  end

  def revenue_projection_history_billed_label(history)
    return t('revenue_projection_histories.show.billed_month') if history.closed?

    t('revenue_projection_histories.show.billed_until', date: l(history.last_closed_date, format: :chart_week))
  end

  def revenue_projection_history_difference_label(history)
    t(history.closed? ? 'difference_closed' : 'difference_open', scope: 'revenue_projection_histories.show')
  end

  def revenue_projection_history_difference_kind(cents)
    cents.negative? ? :danger : :success
  end

  def revenue_projection_history_hit_note(history)
    return t('revenue_projection_histories.show.in_progress_note') unless history.closed?

    hit_since = history.hit_since
    return t('revenue_projection_histories.show.never_hit', tolerance: revenue_projection_history_tolerance) unless hit_since

    t('revenue_projection_histories.show.hit_since', date: l(hit_since, format: :chart_week), tolerance: revenue_projection_history_tolerance)
  end

  def revenue_projection_history_reconstructed_note(history)
    period = history.reconstructed_period
    return unless period

    t('revenue_projection_histories.show.reconstructed', start: l(period.first, format: :chart_week), finish: l(period.last, format: :chart_week))
  end

  def revenue_projection_history_tolerance
    number_to_percentage(Dashboard::RevenueProjectionHistory::HIT_TOLERANCE * 100, precision: 0)
  end
end
