module FreightBillingsHelper
  BRAND_BLUE = '#2563eb'.freeze
  BRAND_ORANGE = '#eb6834'.freeze
  SERIES_COLORS = [BRAND_BLUE, BRAND_ORANGE].freeze
  CHART_GRID_COLOR = '#eef0f4'.freeze
  CHART_TEXT_COLOR = '#52514e'.freeze
  CHART_HEIGHT = '320px'.freeze
  RANKING_BAR_HEIGHT = 44
  RANKING_MIN_HEIGHT = 320

  def freight_billing_content_partial(dashboard)
    dashboard.empty? ? 'shared/no_content' : 'freight_billings/report'
  end

  def freight_billing_dimensions
    Dashboard::Freight::DIMENSIONS
  end

  def freight_billing_dimension_label(dimension)
    t(dimension, scope: 'freight_billings.dimensions')
  end

  def freight_billing_dimension_path(dimension)
    freight_billing_path(**request.query_parameters.symbolize_keys, dimension:)
  end

  def freight_billing_dimension_link_class(dimension, dashboard)
    variation = dimension == dashboard.dimension ? 'btn-primary' : 'btn-outline-secondary'

    "btn btn-sm #{variation}"
  end

  def freight_billing_macro_region_options(macro_regions, selected)
    options = macro_regions.map { |macro_region| [macro_region.name, macro_region.id.to_s] }

    options_for_select(options + [[t('dashboards.freight.none.macro_region'), MacroRegion::OTHERS]], selected)
  end

  def freight_billing_truck_group_options(truck_groups, selected)
    options = truck_groups.map { |truck_group| [truck_group.name, truck_group.id.to_s] }
    options << [t('freight_billings.filters.without_truck_group'), TruckGroup::NONE] if truck_groups.none?(&:remaining_axles?)

    options_for_select(options, selected)
  end

  def freight_billing_period_label(filter_form)
    t('freight_billings.show.period', from: l(filter_form.start_date), to: l(filter_form.end_date))
  end

  def freight_billing_ranking_title(dashboard)
    t('freight_billings.show.ranking_title', dimension: freight_billing_dimension_label(dashboard.dimension))
  end

  def freight_billing_table_title(dashboard)
    t('freight_billings.show.table_title', dimension: freight_billing_dimension_label(dashboard.dimension))
  end

  def freight_billing_history_label(dashboard)
    history = dashboard.history_period

    t('freight_billings.show.monthly_subtitle', from: l(history.first, format: :chart_month).capitalize,
                                                to: l(history.last, format: :chart_month).capitalize)
  end

  def freight_billing_km(distance)
    t('freight_billings.km', distance: number_with_delimiter(distance.round))
  end

  def freight_billing_trips(count)
    number_with_precision(count, precision: 1, strip_insignificant_zeros: true)
  end

  def freight_billing_share(share)
    number_to_percentage(share, precision: 1)
  end

  def freight_billing_ranking_chart(dashboard)
    bar_chart(freight_billing_series(dashboard.ranking_data),
              height: "#{[dashboard.ranking_rows.size * RANKING_BAR_HEIGHT, RANKING_MIN_HEIGHT].max}px",
              legend: 'bottom',
              **freight_billing_money_options,
              library: freight_billing_bar_library(:y))
  end

  def freight_billing_monthly_chart(dashboard)
    column_chart(freight_billing_series(dashboard.monthly_data),
                 height: CHART_HEIGHT,
                 legend: 'bottom',
                 **freight_billing_money_options,
                 library: freight_billing_bar_library(:x))
  end

  private

  def freight_billing_series(series)
    series.zip(SERIES_COLORS).map do |serie, color|
      serie.merge(color:, dataset: { backgroundColor: color, borderWidth: 0, borderRadius: 4, maxBarThickness: 28 })
    end
  end

  def freight_billing_money_options
    { prefix: "#{t('number.currency.format.unit')} ", thousands: t('number.currency.format.delimiter'),
      decimal: t('number.currency.format.separator'), round: 2, zeros: true }
  end

  def freight_billing_bar_library(category_axis)
    value_axis = category_axis == :x ? :y : :x

    {
      scales: {
        category_axis => { grid: { display: false }, ticks: { color: CHART_TEXT_COLOR, autoSkip: false } },
        value_axis => { border: { display: false }, grid: { color: CHART_GRID_COLOR },
                        ticks: { color: CHART_TEXT_COLOR, maxRotation: 0, autoSkipPadding: 16 } },
      },
      plugins: { legend: { labels: { color: CHART_TEXT_COLOR, usePointStyle: true, pointStyle: 'circle', boxWidth: 8, padding: 16 } } },
    }
  end
end
