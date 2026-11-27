module FreightBillingsHelper
  include ChartsHelper

  SERIES_COLORS = [BRAND_BLUE, DANGER_RED].freeze
  COMPARISON_SERIES_COLORS = [BRAND_BLUE, SUCCESS_GREEN].freeze
  DETAIL_MODAL_ID = 'freight_billing_detail_modal'.freeze
  FREIGHTS_MODAL_ID = 'freight_billing_freights_modal'.freeze
  FREIGHTS_FRAME_ID = 'freight_billing_freights'.freeze
  FREIGHTS_SORT_SCOPE = 'freights'.freeze
  PER_KM_ORDERS = %w[desc asc].freeze
  DEFAULT_PER_KM_ORDER = 'desc'.freeze
  FREIGHTS_SORT_COLUMNS = { issued_at: :asc, gross: :desc, net: :desc, gross_per_km: :desc, net_per_km: :desc }.freeze
  TOLL_PAYER_CLASSES = { toll: 'freight-billing-toll-carrier', undiscounted_toll: 'freight-billing-toll-customer' }.freeze

  def freight_billing_content_partial(dashboard)
    dashboard.empty? ? 'shared/no_content' : 'freight_billings/report'
  end

  def freight_billing_dimensions
    Dashboard::Freight::DIMENSIONS
  end

  def freight_billing_dimension_label(dimension)
    t(dimension, scope: 'freight_billings.dimensions')
  end

  def freight_billing_dimension_shortcut(dimension)
    t(dimension, scope: 'freight_billings.dimension_shortcuts')
  end

  def freight_billing_dimension_path(dimension)
    freight_billing_path(**request.query_parameters.symbolize_keys.except(:page), dimension:)
  end

  def freight_billing_dimension_link_class(dimension, dashboard)
    variation = dimension == dashboard.dimension ? 'btn-primary' : 'btn-outline-secondary'

    "btn btn-sm #{variation}"
  end

  def freight_billing_period_presets
    FreightBillingFilterForm::PERIOD_PRESETS
  end

  def freight_billing_period_preset_label(preset)
    t(preset, scope: 'freight_billings.period_presets')
  end

  def freight_billing_period_preset_path(preset)
    period = FreightBillingFilterForm.preset_period(preset)

    freight_billing_path(**request.query_parameters.symbolize_keys.except(:page), start_date: period.first, end_date: period.last)
  end

  def freight_billing_period_preset_link_class(preset, filter_form)
    variation = FreightBillingFilterForm.preset_period(preset) == filter_form.period ? 'btn-primary' : 'btn-outline-secondary'

    "btn btn-sm #{variation}"
  end

  def freight_billing_customer_group_options(customer_groups)
    customer_groups.map { |customer_group| [customer_group.name, customer_group.id.to_s] }
  end

  def freight_billing_product_group_options(product_groups)
    product_groups.map { |product_group| [product_group.name, product_group.id.to_s] }
  end

  def freight_billing_driver_options(drivers)
    drivers.map { |driver| [driver.driver_name.presence || driver.driver_code.to_s, driver.driver_code.to_s] }
  end

  def freight_billing_macro_region_options(macro_regions, selected)
    options = macro_regions.map { |macro_region| [macro_region.name, macro_region.id.to_s] }

    options_for_select(options + [[t('dashboards.freight.none.macro_region'), MacroRegion::OTHERS]], selected)
  end

  def freight_billing_period_label(filter_form)
    t('freight_billings.show.period', from: l(filter_form.start_date), to: l(filter_form.end_date))
  end

  def freight_billing_last_sync_label(last_synced_at)
    return t('freight_billings.show.never_synced') unless last_synced_at

    t('freight_billings.show.last_sync', time: l(last_synced_at, format: :date_time))
  end

  def freight_billing_ranking_title(dashboard)
    t('freight_billings.show.ranking_title', dimension: freight_billing_dimension_label(dashboard.dimension))
  end

  def freight_billing_comparison_ranking_title(dashboard)
    t(dashboard.comparison_unit, scope: 'freight_billings.show.comparison_ranking_title', dimension: freight_billing_dimension_label(dashboard.dimension))
  end

  def freight_billing_comparison_ranking_subtitle(dashboard)
    period = dashboard.period
    previous = dashboard.previous_period
    subtitle = t('freight_billings.show.comparison_ranking_subtitle', from: l(period.first), to: l(period.last),
                                                                      previous_from: l(previous.first), previous_to: l(previous.last))

    safe_join([subtitle, freight_billing_comparison_in_progress(dashboard)].compact, ' ')
  end

  def freight_billing_comparison_headers(dashboard)
    return unless dashboard.comparison?

    safe_join([sortable_header(freight_billing_previous_gross_label(dashboard), :previous_gross, first_direction: :desc, anchor: 'freight_billing_table',
                                                                                                 class: 'd-none d-lg-table-cell text-end'),
               sortable_header(t('freight_billings.columns.variation'), :variation, anchor: 'freight_billing_table', class: 'text-end')])
  end

  def freight_billing_comparison_cells(row, dashboard)
    return unless dashboard.comparison?

    safe_join([tag.td(tax_money(row.previous_gross), class: 'd-none d-lg-table-cell text-end text-nowrap'),
               tag.td(freight_billing_variation(row.variation), class: 'text-end text-nowrap')])
  end

  def freight_billing_variation(variation)
    return t('tax.blank') unless variation

    tag.span(freight_billing_signed_percentage(variation), class: freight_billing_variation_class(variation))
  end

  def freight_billing_signed_percentage(variation)
    return t('tax.blank') unless variation

    formatted = number_to_percentage(variation, precision: 1)

    variation.positive? ? "+#{formatted}" : formatted
  end

  def freight_billing_per_km_ranking_title(dashboard)
    t('freight_billings.show.per_km_ranking_title', dimension: freight_billing_dimension_label(dashboard.dimension))
  end

  def freight_billing_table_title(dashboard)
    t('freight_billings.show.table_title', dimension: freight_billing_dimension_label(dashboard.dimension))
  end

  def freight_billing_monthly_subtitle(dashboard)
    history = dashboard.history_period

    t('freight_billings.show.monthly_subtitle', from: l(history.first, format: :chart_month).capitalize,
                                                to: l(history.last, format: :chart_month).capitalize)
  end

  def freight_billing_weekly_subtitle(dashboard)
    history = dashboard.weekly_history_period

    t('freight_billings.show.weekly_subtitle', from: l(history.first), to: l(history.last))
  end

  def freight_billing_month_period_label(row)
    t('freight_billings.month.period', month: row.label)
  end

  def freight_billing_week_period_label(row)
    t('freight_billings.week.period', from: l(row.period.first), to: l(row.period.last))
  end

  def freight_billing_km(distance)
    t('freight_billings.km', distance: number_with_delimiter(distance.round))
  end

  def freight_billing_per_km_base(dashboard)
    base = dashboard.per_km_base
    return unless base.excluded?

    content_tag(:p, t('freight_billings.show.per_km_base', count: base.excluded_count, gross: tax_money(base.gross), net: tax_money(base.net),
                                                           distance: freight_billing_km(base.loaded_km), excluded_gross: tax_money(base.excluded_gross),
                                                           excluded_net: tax_money(base.excluded_net)),
                class: 'small text-body-secondary mb-4', id: 'per_km_base')
  end

  def freight_billing_trips(count)
    number_with_precision(count, precision: 1, strip_insignificant_zeros: true)
  end

  def freight_billing_share(share)
    number_to_percentage(share, precision: 1)
  end

  def freight_billing_percentage(percentage)
    percentage ? number_to_percentage(percentage, precision: 1) : t('tax.blank')
  end

  def freight_billing_row_menu(row)
    menus = []

    menus << freight_billing_row_show_menu(row) if can?(:read, :freight_billing)

    menus
  end

  def freight_billing_opened_detail(row)
    return unless row

    render 'freight_billings/detail_modal', row:, replace_url: freight_billing_path(request.query_parameters)
  end

  def freight_billing_toll(row)
    tolls = freight_billing_tolls(row)
    return tax_money(row.toll_total) if tolls.empty?

    safe_join(tolls.map { |payer, amount| freight_billing_toll_amount(payer, amount, class: 'd-block') })
  end

  def freight_billing_toll_legend
    tag.div(class: 'freight-billing-toll-legend d-none d-lg-flex') do
      safe_join(TOLL_PAYER_CLASSES.map do |payer, css_class|
        tag.span(t(payer, scope: 'freight_billings.toll_legend'), class: "freight-billing-toll-legend-item #{css_class}")
      end)
    end
  end

  def freight_billing_row_label(row, dashboard)
    return row.label unless dashboard.lists_freights?(row.key)

    link_to row.label, freight_billing_freights_path(row),
            class: 'fw-semibold text-decoration-none', data: { turbo_stream: true }
  end

  def freight_billing_freights_header(column, **)
    sortable_header(freight_billing_freights_column_label(column), column, first_direction: FREIGHTS_SORT_COLUMNS.fetch(column),
                                                                           scope: FREIGHTS_SORT_SCOPE, frame: FREIGHTS_FRAME_ID, **)
  end

  def freight_billing_freights_sort_menu
    columns = FREIGHTS_SORT_COLUMNS.map { |column, first_direction| [freight_billing_freights_column_label(column), column, first_direction] }

    sort_menu(columns, scope: FREIGHTS_SORT_SCOPE, frame: FREIGHTS_FRAME_ID)
  end

  def freight_billing_freights_gross_per_km(freight_lines)
    tax_money(Dashboard::FreightLine.gross_per_km(freight_lines))
  end

  def freight_billing_freights_net_per_km(freight_lines)
    tax_money(Dashboard::FreightLine.net_per_km(freight_lines))
  end

  def freight_billing_detail_sections(row)
    {
      trip: { trips: freight_billing_trips(row.trips_count), loaded_km: freight_billing_km(row.loaded_km) },
      values: { gross: tax_money(row.gross), freight_expenses: tax_money(row.freight_expenses), expenses: tax_money(row.expenses),
                **freight_billing_detail_tolls(row), net: tax_money(row.net) },
      indicators: { gross_per_km: tax_money(row.gross_per_km), net_per_km: tax_money(row.net_per_km), share: freight_billing_share(row.share) },
    }
  end

  def freight_billing_ranking_chart(dashboard)
    tag.div(data: freight_billing_ranking_chart_data(dashboard)) do
      bar_chart(freight_billing_series(dashboard.ranking_data),
                height: "#{[dashboard.ranking_rows.size * RANKING_BAR_HEIGHT, RANKING_MIN_HEIGHT].max}px",
                legend: 'bottom',
                **chart_money_options,
                library: chart_bar_library(:y).deep_merge(plugins: { datalabels: RANKING_BAR_LABELS }))
    end
  end

  def freight_billing_ranking_cards(dashboard)
    cards = [freight_billing_comparison_ranking_card(dashboard), freight_billing_per_km_ranking_card(dashboard)].compact
    return if cards.empty?

    tag.div(class: 'row g-3 mb-4') { safe_join(cards) }
  end

  def freight_billing_comparison_ranking_card(dashboard)
    return unless dashboard.comparison?

    tag.div(class: 'col-12 col-xl-6', id: 'freight_billing_comparison') do
      render('freight_billings/chart_card', title: freight_billing_comparison_ranking_title(dashboard),
                                            subtitle: freight_billing_comparison_ranking_subtitle(dashboard),
                                            chart: freight_billing_comparison_ranking_chart(dashboard))
    end
  end

  def freight_billing_per_km_ranking_card(dashboard)
    return unless dashboard.per_km_ranking?

    return if dashboard.per_km_ranking_data.first[:data].empty?

    tag.div(class: 'col-12 col-xl-6 d-flex flex-column', id: 'freight_billing_per_km', data: freight_billing_per_km_reveal_data) do
      safe_join([freight_billing_per_km_order_filter, *PER_KM_ORDERS.map { |order| freight_billing_per_km_order_item(dashboard, order) }])
    end
  end

  def freight_billing_evolution_cards(dashboard)
    safe_join(chart_evolutions.map do |evolution|
      chart_evolution_item(evolution) do
        render 'freight_billings/chart_card', title: t("freight_billings.show.#{evolution}_title"),
                                              subtitle: public_send(:"freight_billing_#{evolution}_subtitle", dashboard),
                                              chart: freight_billing_history_chart(dashboard, evolution)
      end
    end)
  end

  def freight_billing_pdf_report(dashboard, rows, filter_form)
    PdfReport.new(
      title: t('freight_billings.show.pdf.header'),
      subtitle: t('freight_billings.show.pdf.subtitle', table: freight_billing_table_title(dashboard), period: freight_billing_period_label(filter_form)),
      highlights: freight_billing_pdf_highlights(dashboard),
      columns: freight_billing_pdf_columns(dashboard),
      rows: rows.map { |row| freight_billing_pdf_row(row, dashboard) },
      totals: (freight_billing_pdf_row(dashboard.total, dashboard) unless dashboard.empty?),
    )
  end

  def freight_billing_pdf_columns(dashboard)
    [pdf_column(freight_billing_dimension_label(dashboard.dimension), '3fr'),
     *freight_billing_pdf_column_names(dashboard).map { |column| pdf_column(freight_billing_pdf_column_label(column, dashboard), align: :right) }]
  end

  def freight_billing_pdf_row(row, dashboard)
    [freight_billing_row_label(row, dashboard), freight_billing_trips(row.trips_count), freight_billing_km(row.loaded_km), tax_money(row.gross),
     *([tax_money(row.previous_gross), freight_billing_signed_percentage(row.variation)] if dashboard.comparison?),
     tax_money(row.net), tax_money(row.toll_total), tax_money(row.gross_per_km), tax_money(row.net_per_km), freight_billing_share(row.share)]
  end

  def freight_billing_pdf_highlights(dashboard)
    total = dashboard.total

    [pdf_highlight(t('freight_billings.show.gross'), tax_money(dashboard.gross)), pdf_highlight(t('freight_billings.show.net'), tax_money(dashboard.net)),
     pdf_highlight(t('freight_billings.show.trips'), freight_billing_trips(total.trips_count)),
     pdf_highlight(t('freight_billings.show.gross_per_km'), tax_money(total.gross_per_km)),
     pdf_highlight(t('freight_billings.show.net_per_km'), tax_money(total.net_per_km)),
     pdf_highlight(t('freight_billings.show.loaded_km'), freight_billing_km(total.loaded_km)),
     pdf_highlight(t('freight_billings.show.empty_km'), freight_billing_km(total.empty_km)),
     pdf_highlight(t('freight_billings.show.empty_share'), freight_billing_percentage(total.empty_share))]
  end

  def freight_billing_xlsx_sheets(dashboard, rows)
    columns = [xlsx_field(freight_billing_dimension_label(dashboard.dimension), &:label),
               xlsx_field(t('freight_billings.columns.trips'), :decimal, &:trips_count),
               xlsx_field(t('freight_billings.columns.loaded_km'), :decimal, &:loaded_km),
               xlsx_field(t('freight_billings.show.empty_km'), :decimal, &:empty_km),
               xlsx_field(t('freight_billings.show.empty_share'), :percentage, &:empty_share),
               *%i[gross freight_expenses expenses toll undiscounted_toll net gross_per_km net_per_km].map do |column|
                 xlsx_field(t(column, scope: 'freight_billings.columns'), :money, &column)
               end,
               xlsx_field(t('freight_billings.columns.share'), :percentage, &:share),
               *freight_billing_comparison_xlsx_fields(dashboard)]

    [Export::Sheet.new(name: freight_billing_table_title(dashboard), columns:, rows: dashboard.empty? ? rows : [*rows, dashboard.total])]
  end

  private

  def freight_billing_pdf_column_names(dashboard)
    comparison = %i[previous_gross variation] if dashboard.comparison?

    [:trips, :loaded_km, :gross, *comparison, :net, :toll_total, :gross_per_km, :net_per_km, :share]
  end

  def freight_billing_comparison_xlsx_fields(dashboard)
    return [] unless dashboard.comparison?

    [xlsx_field(freight_billing_previous_gross_label(dashboard), :money, &:previous_gross),
     xlsx_field(t('freight_billings.columns.variation'), :percentage, &:variation)]
  end

  def freight_billing_detail_tolls(row)
    tolls = freight_billing_tolls(row)
    return { toll_total: tax_money(row.toll_total) } if tolls.empty?

    tolls.to_h { |payer, amount| [payer, freight_billing_toll_amount(payer, amount)] }
  end

  def freight_billing_tolls(row)
    { toll: row.toll, undiscounted_toll: row.undiscounted_toll }.select { |_payer, amount| amount.positive? }
  end

  def freight_billing_toll_amount(payer, amount, **options)
    tag.span(tax_money(amount), class: [TOLL_PAYER_CLASSES.fetch(payer), options[:class]], title: t(payer, scope: 'freight_billings.toll_legend'))
  end

  def freight_billing_freights_column_label(column)
    case column
    when :gross_per_km, :net_per_km then t(column, scope: 'freight_billings.columns')
    else Atua::TransportDocument.human_attribute_name(column)
    end
  end

  def freight_billing_freights_path(row)
    freights_freight_billing_path(**request.query_parameters.symbolize_keys, key: row.key)
  end

  def freight_billing_per_km_reveal_data
    { controller: 'reveal', reveal_key_value: DEFAULT_PER_KM_ORDER, reveal_active_class: 'btn-primary',
      reveal_inactive_class: 'btn-outline-secondary', reveal_hidden_class: 'd-none' }
  end

  def freight_billing_per_km_order_filter
    label = t('freight_billings.show.per_km_order_label')

    tag.div(class: 'dashboard-filter-bar mb-3') do
      safe_join([tag.span(label, class: 'dashboard-filter-label'),
                 tag.div(class: 'dashboard-segmented', role: 'group', aria: { label: }) do
                   safe_join(PER_KM_ORDERS.map { |order| freight_billing_per_km_order_button(order) })
                 end])
    end
  end

  def freight_billing_per_km_order_button(order)
    default = order == DEFAULT_PER_KM_ORDER

    button_tag t(order, scope: 'freight_billings.show.per_km_orders'), type: :button, class: ['btn btn-sm', default ? 'btn-primary' : 'btn-outline-secondary'],
                                                                       aria: { pressed: default },
                                                                       data: { reveal_target: 'button', reveal_key_param: order, action: 'reveal#show' }
  end

  def freight_billing_per_km_order_item(dashboard, order)
    tag.div(class: ['flex-grow-1', ('d-none' unless order == DEFAULT_PER_KM_ORDER)], data: { reveal_target: 'item', reveal_key: order }) do
      render('freight_billings/chart_card', title: freight_billing_per_km_ranking_title(dashboard),
                                            subtitle: t('freight_billings.show.per_km_ranking_subtitle'),
                                            chart: freight_billing_per_km_ranking_chart(dashboard.per_km_ranking_data(order)))
    end
  end

  def freight_billing_per_km_ranking_chart(data)
    bar_chart(freight_billing_series(data),
              height: "#{[data.first[:data].size * RANKING_BAR_HEIGHT, RANKING_MIN_HEIGHT].max}px",
              legend: 'bottom',
              **chart_money_options,
              library: chart_bar_library(:y).deep_merge(plugins: { datalabels: RANKING_BAR_LABELS }))
  end

  def freight_billing_comparison_in_progress(dashboard)
    period = dashboard.period
    return unless period.cover?(Date.current) && period.last > Date.current

    t(dashboard.comparison_unit, scope: 'freight_billings.show.comparison_in_progress', today: l(Date.current))
  end

  def freight_billing_previous_gross_label(dashboard)
    t(dashboard.comparison_unit, scope: 'freight_billings.columns.previous_gross')
  end

  def freight_billing_pdf_column_label(column, dashboard)
    return freight_billing_previous_gross_label(dashboard) if column == :previous_gross

    t(column, scope: 'freight_billings.columns')
  end

  def freight_billing_variation_class(variation)
    if variation.positive?
      'text-success'
    elsif variation.negative?
      'text-danger'
    end
  end

  def freight_billing_comparison_ranking_chart(dashboard)
    bar_chart(freight_billing_series(dashboard.comparison_ranking_data, COMPARISON_SERIES_COLORS),
              height: "#{[dashboard.ranking_rows.size * RANKING_BAR_HEIGHT, RANKING_MIN_HEIGHT].max}px",
              legend: 'bottom',
              **chart_money_options,
              library: chart_bar_library(:y).deep_merge(plugins: { datalabels: RANKING_BAR_LABELS }))
  end

  def freight_billing_ranking_chart_data(dashboard)
    return {} unless dashboard.ranking_rows.all? { |row| dashboard.lists_freights?(row.key) }

    { controller: 'ranking-chart', ranking_chart_urls_value: dashboard.ranking_rows.map { |row| freight_billing_freights_path(row) },
      action: 'click->ranking-chart#open mousemove->ranking-chart#hover' }
  end

  def freight_billing_history_chart(dashboard, evolution)
    tag.div(data: freight_billing_history_chart_data(dashboard, evolution)) do
      bar_chart(freight_billing_series(dashboard.public_send(:"#{evolution}_data")),
                height: CHART_HEIGHT,
                legend: 'bottom',
                **chart_money_options,
                library: chart_bar_library(:y).deep_merge(plugins: { datalabels: RANKING_BAR_LABELS, tooltip: { enabled: false } }))
    end
  end

  def freight_billing_history_chart_data(dashboard, evolution)
    { controller: 'ranking-chart', ranking_chart_urls_value: send(:"freight_billing_#{evolution}_urls", dashboard),
      action: 'click->ranking-chart#open mousemove->ranking-chart#hover' }
  end

  def freight_billing_monthly_urls(dashboard)
    dashboard.billed_months.map do |month, billed|
      month_freight_billing_path(**request.query_parameters.symbolize_keys, month: month.strftime(Dashboard::Freight::MONTH_FORMAT)) if billed
    end
  end

  def freight_billing_weekly_urls(dashboard)
    dashboard.billed_weeks.map do |week, billed|
      week_freight_billing_path(**request.query_parameters.symbolize_keys, week: week.strftime(Dashboard::Freight::WEEK_FORMAT)) if billed
    end
  end

  def freight_billing_row_show_menu(row)
    Menu.new(
      name: :show,
      record: row,
      url: detail_freight_billing_path(**request.query_parameters.symbolize_keys, key: row.key),
      icon: :eye,
      data: { turbo_stream: true },
    )
  end

  def freight_billing_series(series, colors = SERIES_COLORS)
    series.zip(colors).map do |serie, color|
      serie.merge(color:, dataset: { backgroundColor: color, borderWidth: 0, borderRadius: 4, maxBarThickness: 28 })
    end
  end
end
