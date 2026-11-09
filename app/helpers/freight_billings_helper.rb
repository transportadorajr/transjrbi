module FreightBillingsHelper
  include ChartsHelper

  SERIES_COLORS = [BRAND_BLUE, DANGER_RED].freeze
  DETAIL_MODAL_ID = 'freight_billing_detail_modal'.freeze
  FREIGHTS_MODAL_ID = 'freight_billing_freights_modal'.freeze

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

  def freight_billing_truck_group_options(truck_groups, selected)
    options_for_select(truck_groups.map { |truck_group| [truck_group.name, truck_group.id.to_s] }, selected)
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

  def freight_billing_per_km_ranking_title(dashboard)
    t('freight_billings.show.per_km_ranking_title', dimension: freight_billing_dimension_label(dashboard.dimension))
  end

  def freight_billing_table_title(dashboard)
    t('freight_billings.show.table_title', dimension: freight_billing_dimension_label(dashboard.dimension))
  end

  def freight_billing_history_label(dashboard)
    history = dashboard.history_period

    t('freight_billings.show.monthly_subtitle', from: l(history.first, format: :chart_month).capitalize,
                                                to: l(history.last, format: :chart_month).capitalize)
  end

  def freight_billing_month_period_label(row)
    t('freight_billings.month.period', month: row.label)
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

  def freight_billing_row_label(row, dashboard)
    return row.label unless dashboard.lists_freights?(row.key)

    link_to row.label, freight_billing_freights_path(row),
            class: 'fw-semibold text-decoration-none', data: { turbo_stream: true }
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

  def freight_billing_per_km_ranking_card(dashboard)
    return unless dashboard.per_km_ranking?

    data = dashboard.per_km_ranking_data
    return if data.first[:data].empty?

    tag.div(class: 'row g-3 mb-4') do
      tag.div(class: 'col-12 col-xl-7') do
        render('freight_billings/chart_card', title: freight_billing_per_km_ranking_title(dashboard),
                                              subtitle: t('freight_billings.show.per_km_ranking_subtitle'),
                                              chart: freight_billing_per_km_ranking_chart(data))
      end
    end
  end

  def freight_billing_monthly_chart(dashboard)
    tag.div(data: freight_billing_monthly_chart_data(dashboard)) do
      bar_chart(freight_billing_series(dashboard.monthly_data),
                height: CHART_HEIGHT,
                legend: 'bottom',
                **chart_money_options,
                library: chart_bar_library(:y).deep_merge(plugins: { datalabels: RANKING_BAR_LABELS, tooltip: { enabled: false } }))
    end
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
     *%i[trips loaded_km gross net toll_total gross_per_km net_per_km share].map do |column|
       pdf_column(t(column, scope: 'freight_billings.columns'), align: :right)
     end]
  end

  def freight_billing_pdf_row(row, dashboard)
    [freight_billing_row_label(row, dashboard), freight_billing_trips(row.trips_count), freight_billing_km(row.loaded_km), tax_money(row.gross),
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

  private

  def freight_billing_detail_tolls(row)
    return { toll: tax_money(row.toll) } unless row.undiscounted_toll.positive?

    tolls = { undiscounted_toll: tax_money(row.undiscounted_toll) }
    row.toll.positive? ? { toll: tax_money(row.toll), **tolls } : tolls
  end

  def freight_billing_freights_path(row)
    freights_freight_billing_path(**request.query_parameters.symbolize_keys, key: row.key)
  end

  def freight_billing_per_km_ranking_chart(data)
    bar_chart(freight_billing_series(data),
              height: "#{[data.first[:data].size * RANKING_BAR_HEIGHT, RANKING_MIN_HEIGHT].max}px",
              legend: 'bottom',
              **chart_money_options,
              library: chart_bar_library(:y).deep_merge(plugins: { datalabels: RANKING_BAR_LABELS }))
  end

  def freight_billing_ranking_chart_data(dashboard)
    return {} unless dashboard.ranking_rows.all? { |row| dashboard.lists_freights?(row.key) }

    { controller: 'ranking-chart', ranking_chart_urls_value: dashboard.ranking_rows.map { |row| freight_billing_freights_path(row) },
      action: 'click->ranking-chart#open mousemove->ranking-chart#hover' }
  end

  def freight_billing_monthly_chart_data(dashboard)
    { controller: 'ranking-chart', ranking_chart_urls_value: freight_billing_month_urls(dashboard),
      action: 'click->ranking-chart#open mousemove->ranking-chart#hover' }
  end

  def freight_billing_month_urls(dashboard)
    dashboard.billed_months.map do |month, billed|
      month_freight_billing_path(**request.query_parameters.symbolize_keys, month: month.strftime(Dashboard::Freight::MONTH_FORMAT)) if billed
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

  def freight_billing_series(series)
    series.zip(SERIES_COLORS).map do |serie, color|
      serie.merge(color:, dataset: { backgroundColor: color, borderWidth: 0, borderRadius: 4, maxBarThickness: 28 })
    end
  end
end
