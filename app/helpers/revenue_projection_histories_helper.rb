module RevenueProjectionHistoriesHelper
  HISTORY_PROJECTED_ORANGE = '#f97316'.freeze
  HISTORY_LOW_HIGH_GRAY = '#cbd5e1'.freeze
  HISTORY_PROJECTED_STYLE = { color: HISTORY_PROJECTED_ORANGE,
                              dataset: { borderColor: HISTORY_PROJECTED_ORANGE,
                                         backgroundColor: HISTORY_PROJECTED_ORANGE } }.freeze
  HISTORY_RANGE_STYLE = { color: HISTORY_LOW_HIGH_GRAY,
                          dataset: { borderColor: HISTORY_LOW_HIGH_GRAY, backgroundColor: HISTORY_LOW_HIGH_GRAY, borderDash: [4, 4], borderWidth: 1 } }.freeze
  HISTORY_REALIZED_STYLE = { color: ChartsHelper::BRAND_BLUE,
                             dataset: { borderColor: ChartsHelper::BRAND_BLUE, backgroundColor: ChartsHelper::BRAND_BLUE } }.freeze
  HISTORY_BILLED_STYLE = { color: ChartsHelper::BRAND_BLUE,
                           dataset: { borderColor: ChartsHelper::BRAND_BLUE, backgroundColor: ChartsHelper::BRAND_BLUE, borderDash: [6, 4] } }.freeze
  HISTORY_SERIES = [HISTORY_PROJECTED_STYLE, HISTORY_RANGE_STYLE, HISTORY_RANGE_STYLE, HISTORY_REALIZED_STYLE, HISTORY_BILLED_STYLE].freeze
  HISTORY_DAYS_SERIES = [HISTORY_PROJECTED_STYLE, HISTORY_REALIZED_STYLE].freeze
  HISTORY_DATE_TICKS = 8
  HISTORY_CARD_COLUMNS = 'col-12 col-md-6 col-xxl-3'.freeze
  HISTORY_RANGE_CARD_COLUMNS = 'col-12 col-md-6 col-xxl-4'.freeze
  HISTORY_DAY_COLUMNS = 7

  def revenue_projection_period_link_class(period_type, selected)
    "btn btn-sm #{period_type == selected ? 'btn-primary' : 'btn-outline-secondary'}"
  end

  def revenue_projection_history_body(history)
    return render('shared/no_content') unless history.any?
    return render('revenue_projection_histories/today', today: history) if history.period_type == 'today'

    render 'revenue_projection_histories/content', history:
  end

  def revenue_projection_history_period_presets
    RevenueProjectionHistoryFilterForm::PERIOD_PRESETS
  end

  def revenue_projection_history_preset_path(preset)
    period = RevenueProjectionHistoryFilterForm.preset_period(preset)

    revenue_projection_history_path(start_date: period.first, end_date: period.last, **revenue_projection_history_cut_params)
  end

  def revenue_projection_history_cut_params
    request.query_parameters.slice(*FreightDocumentFilters::FILTER_PARAMS.map(&:to_s)).compact_blank.symbolize_keys
  end

  def revenue_projection_history_cut(cut_items)
    return if cut_items.empty?

    items = cut_items.map { |label, value| t('revenue_projection_histories.show.cut_item', label:, value:) }
    tag.div(id: 'history_cut', class: 'mb-4') do
      safe_join([tag.div(safe_join([tag.span(t('revenue_projection_histories.show.cut_label'), class: 'dashboard-filter-label'),
                                    tag.span(items.join(' · '), class: 'small fw-semibold')]), class: 'dashboard-filter-bar mb-1'),
                 tag.p(t('revenue_projection_histories.show.cut_note'), class: 'small text-muted mb-0')])
    end
  end

  def revenue_projection_history_macro_region_name(macro_regions, value)
    return t('dashboards.freight.none.macro_region') if value == MacroRegion::OTHERS

    macro_regions.find_by(id: value)&.name
  end

  def revenue_projection_history_start_select(history)
    return unless history.try(:snapshot_period?)

    render 'revenue_projection_histories/start_select', history:
  end

  def revenue_projection_history_start_options(history)
    history.starts.map do |start|
      [revenue_projection_history_period_name(history.period_type, RevenueProjectionHistoryFilterForm.snapshot_period(history.period_type, start)), start.iso8601]
    end
  end

  def revenue_projection_history_period_name(period_type, period)
    return l(period.first, format: :month_name).capitalize if period_type.to_s == 'month'
    return t('revenue_projection_histories.show.week_option', start: l(period.first, format: :chart_week), finish: l(period.last)) if period_type.to_s == 'week'

    t('revenue_projection_histories.show.range_option', start: l(period.first), finish: l(period.last))
  end

  def revenue_projection_history_weeks(history)
    render 'revenue_projection_histories/weeks_table', rows: history.week_rows if history.week_rows.any?
  end

  def revenue_projection_history_cards(history)
    return revenue_projection_history_range_cards(history) unless history.snapshot_period?

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
    styles = history.snapshot_period? ? HISTORY_SERIES : HISTORY_DAYS_SERIES

    line_chart(history.chart_data.zip(styles).map { |serie, style| serie.merge(style) },
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

  def revenue_projection_history_difference_kind(cents)
    cents.negative? ? :danger : :success
  end

  def revenue_projection_history_day_menu(row, history)
    menus = []
    menus << revenue_projection_history_note_menu(row, history) if can?(:update, :revenue_projection_notes)
    menus
  end

  def revenue_projection_history_note_row(row)
    return unless row.note

    tag.tr(class: 'history-note-row') do
      tag.td(colspan: HISTORY_DAY_COLUMNS, class: 'small text-muted pt-0') do
        safe_join([icon(:'journal-text'), tag.span(row.note.body, class: 'fst-italic text-wrap'),
                   tag.span(t('revenue_projection_histories.show.note_author', name: row.note.user.name))], ' ')
      end
    end
  end

  def revenue_projection_history_export_button(history)
    xlsx_export_button if history.any?
  end

  def revenue_projection_history_tolerance
    number_to_percentage(Dashboard::RevenueProjectionHistory::HIT_TOLERANCE * 100, precision: 0)
  end

  private

  def revenue_projection_history_range_cards(history)
    safe_join([
                counter_card(:warning, revenue_projection_history_range_forecast_label(history), tax_money(Money.from_cents(history.forecast_cents)),
                             col_class: HISTORY_RANGE_CARD_COLUMNS),
                counter_card(:primary, revenue_projection_history_billed_label(history), tax_money(Money.from_cents(history.billed_cents)),
                             col_class: HISTORY_RANGE_CARD_COLUMNS),
                counter_card(revenue_projection_history_difference_kind(history.difference_cents), t('revenue_projection_histories.show.difference_range'),
                             revenue_projection_history_difference(history.difference_cents, history.difference_ratio),
                             col_class: HISTORY_RANGE_CARD_COLUMNS),
              ])
  end

  def revenue_projection_history_note_menu(row, history)
    url = edit_revenue_projection_day_note_path(row.date.iso8601, start_date: history.period.first, end_date: history.period.last,
                                                                  **revenue_projection_history_cut_params)

    Menu.new(name: :note, record: row, url:, icon: :'journal-text', data: { turbo_stream: true })
  end

  def revenue_projection_history_opening_label(history)
    t('revenue_projection_histories.show.opening', date: l(history.opening.taken_on, format: :chart_week))
  end

  def revenue_projection_history_latest_label(history)
    key = history.closed? ? 'final_projection' : 'latest_projection'
    t(key, scope: 'revenue_projection_histories.show', date: l(history.latest.taken_on, format: :chart_week))
  end

  def revenue_projection_history_range_forecast_label(history)
    t('revenue_projection_histories.show.range_forecast', date: l(history.last_closed_date, format: :chart_week))
  end

  def revenue_projection_history_billed_label(history)
    return t(history.period_type, scope: 'revenue_projection_histories.show.billed_period') if history.closed?

    t('revenue_projection_histories.show.billed_until', date: l(history.last_closed_date, format: :chart_week))
  end

  def revenue_projection_history_difference_label(history)
    t(history.closed? ? 'difference_closed' : 'difference_open', scope: 'revenue_projection_histories.show')
  end

  def revenue_projection_history_hit_note(history)
    return t(history.period_type, scope: 'revenue_projection_histories.show.in_progress_note') unless history.closed?
    return unless history.snapshot_period?

    hit_since = history.hit_since
    return t('revenue_projection_histories.show.never_hit', tolerance: revenue_projection_history_tolerance) unless hit_since

    t('revenue_projection_histories.show.hit_since', date: l(hit_since, format: :chart_week), tolerance: revenue_projection_history_tolerance)
  end

  def revenue_projection_history_reconstructed_note(history)
    period = history.reconstructed_period
    return unless period

    t('revenue_projection_histories.show.reconstructed', start: l(period.first, format: :chart_week), finish: l(period.last, format: :chart_week))
  end
end
