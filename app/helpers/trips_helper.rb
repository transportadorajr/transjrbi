module TripsHelper
  include ChartsHelper

  SERIES_COLORS = [BRAND_BLUE, DANGER_RED].freeze

  def trips_content_partial(dashboard)
    dashboard.empty? ? 'shared/no_content' : 'trips/report'
  end

  def trips_dimensions
    Dashboard::Trip::DIMENSIONS
  end

  def trips_dimension_label(dimension)
    t(dimension, scope: 'trips.dimensions')
  end

  def trips_dimension_path(dimension)
    trips_path(**request.query_parameters.symbolize_keys.except(:page, :sort, :direction), dimension:)
  end

  def trips_dimension_link_class(dimension, dashboard)
    variation = dimension == dashboard.dimension ? 'btn-primary' : 'btn-outline-secondary'

    "btn btn-sm #{variation}"
  end

  def trips_evolution_cards(dashboard, metric)
    suffix = metric == :per_km ? '_per_km' : ''

    safe_join(EVOLUTIONS.map do |evolution|
      chart_evolution_item(evolution) do
        render 'freight_billings/chart_card', title: t("trips.index.#{evolution}#{suffix}_title"),
                                              subtitle: public_send(:"trips_#{evolution}_subtitle", dashboard),
                                              chart: public_send(:"trips_#{evolution}_chart", dashboard.public_send(:"#{evolution}#{suffix}_data"))
      end
    end)
  end

  def trips_period_presets
    TripFilterForm::PERIOD_PRESETS
  end

  def trips_period_preset_label(preset)
    t(preset, scope: 'trips.period_presets')
  end

  def trips_period_preset_path(preset)
    period = TripFilterForm.preset_period(preset)

    trips_path(**request.query_parameters.symbolize_keys.except(:page), start_date: period.first, end_date: period.last)
  end

  def trips_period_preset_link_class(preset, filter_form)
    variation = filter_form.preset_period(preset) == filter_form.period ? 'btn-primary' : 'btn-outline-secondary'

    "btn btn-sm #{variation}"
  end

  def trips_driver_options(drivers)
    drivers.map { |driver| [driver.driver_name.presence || driver.driver_code.to_s, driver.driver_code.to_s] }
  end

  def trips_product_group_options(product_groups)
    product_groups.map { |product_group| [product_group.name, product_group.id.to_s] }
  end

  def trips_truck_group_options(truck_groups, selected)
    options_for_select(truck_groups.map { |truck_group| [truck_group.name, truck_group.id.to_s] }, selected)
  end

  def trips_period_label(filter_form)
    t('trips.index.period', from: l(filter_form.start_date), to: l(filter_form.end_date))
  end

  def trips_last_sync_label(last_synced_at)
    return t('trips.index.never_synced') unless last_synced_at

    t('trips.index.last_sync', time: l(last_synced_at, format: :date_time))
  end

  def trips_ranking_title(dashboard)
    t('trips.index.ranking_title', dimension: trips_dimension_label(dashboard.dimension))
  end

  def trips_per_km_ranking_title(dashboard)
    t('trips.index.per_km_ranking_title', dimension: trips_dimension_label(dashboard.dimension))
  end

  def trips_table_title(dashboard)
    t('trips.index.table_title', dimension: trips_dimension_label(dashboard.dimension))
  end

  def trips_monthly_subtitle(dashboard)
    months = dashboard.months

    t('trips.index.monthly_subtitle', from: l(months.first, format: :chart_month).capitalize, to: l(months.last, format: :chart_month).capitalize)
  end

  def trips_weekly_subtitle(dashboard)
    weeks = dashboard.weeks

    t('trips.index.weekly_subtitle', from: l(weeks.first), to: l(weeks.last.end_of_week(Dashboard::Trip::WEEK_START)))
  end

  def trips_row_class(row, highlights)
    { best: 'table-success', worst: 'table-danger' }[highlights[row.key]]
  end

  def trips_row_label(row, highlights)
    label = row.manifest_id && can?(:read, :manifests) ? link_to(row.label, manifest_path(row.manifest_id), class: 'fw-semibold') : row.label
    parts = [content_tag(:span, label, class: 'fw-semibold')]
    parts << content_tag(:span, row.detail, class: 'd-block text-body-secondary small') if row.detail
    parts << trips_highlight_badge(highlights[row.key]) if highlights[row.key]

    safe_join(parts, ' ')
  end

  def trips_per_km_base(dashboard)
    base = dashboard.per_km_base
    return unless base.excluded?

    content_tag(:p, t('trips.index.per_km_base', count: base.excluded_count, gross: tax_money(base.gross), net: tax_money(base.net),
                                                 distance: trips_km(base.loaded_km), excluded_gross: tax_money(base.excluded_gross),
                                                 excluded_net: tax_money(base.excluded_net)),
                class: 'small text-body-secondary mb-4', id: 'per_km_base')
  end

  def trips_unmeasured_alert(trips)
    return if trips.empty?

    render 'trips/unmeasured_alert', trips:
  end

  def trips_unmeasured_item(trip)
    number = can?(:read, :manifests) ? link_to(trip.number, manifest_path(trip.id), class: 'fw-semibold') : trip.number

    safe_join([number, content_tag(:span, t('trips.unmeasured_alert.item', plate: trip.plate, date: l(trip.trip_on), distance: trips_km(trip.loaded_km)),
                                   class: 'text-body-secondary')], ' ')
  end

  def trips_sort_columns(dashboard)
    [[trips_dimension_label(dashboard.dimension), :label], [t('trips.columns.trips'), :trips, :desc], [t('trips.columns.gross'), :gross, :desc],
     [t('trips.columns.expenses'), :expenses, :desc], [t('trips.columns.net'), :net, :desc], [t('trips.columns.average'), :average, :desc],
     [t('trips.columns.gross_per_km'), :gross_per_km, :desc], [t('trips.columns.net_per_km'), :net_per_km, :desc]]
  end

  def trips_km(distance)
    t('trips.km', distance: number_with_delimiter(distance.round))
  end

  def trips_ranking_chart(data)
    bar_chart(trips_series(data), height: "#{[data.first[:data].size * RANKING_BAR_HEIGHT, RANKING_MIN_HEIGHT].max}px", legend: 'bottom',
                                  **chart_money_options, library: chart_bar_library(:y).deep_merge(plugins: { datalabels: RANKING_BAR_LABELS }))
  end

  def trips_monthly_chart(data)
    column_chart(trips_series(data), height: CHART_HEIGHT, legend: 'bottom', **chart_money_options, library: chart_bar_library(:x))
  end

  def trips_weekly_chart(data)
    bar_chart(trips_series(data), height: CHART_HEIGHT, legend: 'bottom', **chart_money_options,
                                  library: chart_bar_library(:y).deep_merge(plugins: { datalabels: RANKING_BAR_LABELS, tooltip: { enabled: false } }))
  end

  def trips_pdf_report(dashboard, rows, filter_form, highlights)
    PdfReport.new(
      title: t('trips.index.pdf.header'),
      subtitle: t('trips.index.pdf.subtitle', dimension: trips_dimension_label(dashboard.dimension), period: trips_period_label(filter_form)),
      highlights: trips_pdf_highlights(dashboard.total),
      columns: trips_pdf_columns(dashboard),
      rows: rows.map { |row| trips_pdf_row(row, highlights) },
      totals: (trips_pdf_row(dashboard.total, {}) unless dashboard.empty?),
    )
  end

  def trips_pdf_columns(dashboard)
    [pdf_column(trips_dimension_label(dashboard.dimension), '3fr'),
     *%i[trips loaded_km gross expenses net average gross_per_km net_per_km].map { |column| pdf_column(t(column, scope: 'trips.columns'), align: :right) }]
  end

  def trips_pdf_row(row, highlights)
    [trips_row_label(row, highlights), row.trips_count, trips_km(row.loaded_km), tax_money(row.gross), tax_money(row.expenses), tax_money(row.net),
     tax_money(row.average), tax_money(row.gross_per_km), tax_money(row.net_per_km)]
  end

  def trips_pdf_highlights(total)
    [pdf_highlight(t('trips.index.trips'), total.trips_count), pdf_highlight(t('trips.index.gross'), tax_money(total.gross)),
     pdf_highlight(t('trips.index.average'), tax_money(total.average)), pdf_highlight(t('trips.index.gross_per_km'), tax_money(total.gross_per_km)),
     pdf_highlight(t('trips.index.loaded_km'), trips_km(total.loaded_km)), pdf_highlight(t('trips.index.net'), tax_money(total.net)),
     pdf_highlight(t('trips.index.net_average'), tax_money(total.net_average)), pdf_highlight(t('trips.index.net_per_km'), tax_money(total.net_per_km))]
  end

  private

  def trips_highlight_badge(highlight)
    status_badge(t(highlight, scope: 'trips.highlights'), kind: highlight == :best ? :success : :danger)
  end

  def trips_series(series)
    series.zip(SERIES_COLORS).map do |serie, color|
      serie.merge(color:, dataset: { backgroundColor: color, borderWidth: 0, borderRadius: 4, maxBarThickness: 28 })
    end
  end
end
