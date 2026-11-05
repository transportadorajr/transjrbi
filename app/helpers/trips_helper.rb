module TripsHelper
  include ChartsHelper

  SERIES_COLORS = [BRAND_BLUE, DANGER_RED].freeze
  EVOLUTIONS = %w[monthly weekly].freeze
  DEFAULT_EVOLUTION = 'monthly'.freeze

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

  def trips_evolutions
    EVOLUTIONS
  end

  def trips_evolution_reveal_data
    { controller: 'reveal', reveal_key_value: DEFAULT_EVOLUTION, reveal_active_class: 'btn-primary',
      reveal_inactive_class: 'btn-outline-secondary', reveal_hidden_class: 'd-none' }
  end

  def trips_evolution_button(evolution)
    default = evolution == DEFAULT_EVOLUTION

    button_tag t(evolution, scope: 'trips.evolutions'), type: :button, class: ['btn btn-sm', default ? 'btn-primary' : 'btn-outline-secondary'],
                                                        aria: { pressed: default },
                                                        data: { reveal_target: 'button', reveal_key_param: evolution, action: 'reveal#show' }
  end

  def trips_evolution_cards(dashboard, metric)
    suffix = metric == :per_km ? '_per_km' : ''

    safe_join(EVOLUTIONS.map do |evolution|
      tag.div(class: ['h-100', ('d-none' unless evolution == DEFAULT_EVOLUTION)], data: { reveal_target: 'item', reveal_key: evolution }) do
        render 'freight_billings/chart_card', title: t("trips.index.#{evolution}#{suffix}_title"),
                                              subtitle: public_send(:"trips_#{evolution}_subtitle", dashboard),
                                              chart: trips_history_chart(dashboard.public_send(:"#{evolution}#{suffix}_data"))
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

  def trips_sort_columns(dashboard)
    [[trips_dimension_label(dashboard.dimension), :label], [t('trips.columns.trips'), :trips, :desc], [t('trips.columns.gross'), :gross, :desc],
     [t('trips.columns.net'), :net, :desc], [t('trips.columns.average'), :average, :desc], [t('trips.columns.gross_per_km'), :gross_per_km, :desc],
     [t('trips.columns.net_per_km'), :net_per_km, :desc]]
  end

  def trips_km(distance)
    t('trips.km', distance: number_with_delimiter(distance.round))
  end

  def trips_ranking_chart(data)
    bar_chart(trips_series(data), height: "#{[data.first[:data].size * RANKING_BAR_HEIGHT, RANKING_MIN_HEIGHT].max}px", legend: 'bottom',
                                  **chart_money_options, library: chart_bar_library(:y).deep_merge(plugins: { datalabels: RANKING_BAR_LABELS }))
  end

  def trips_history_chart(data)
    column_chart(trips_series(data), height: CHART_HEIGHT, legend: 'bottom', **chart_money_options, library: chart_bar_library(:x))
  end

  private

  def trips_series(series)
    series.zip(SERIES_COLORS).map do |serie, color|
      serie.merge(color:, dataset: { backgroundColor: color, borderWidth: 0, borderRadius: 4, maxBarThickness: 28 })
    end
  end
end
