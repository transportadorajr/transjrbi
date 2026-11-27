module FleetProductivitiesHelper
  include ChartsHelper

  def fleet_productivity_period_label(filter_form)
    t('fleet_productivities.show.period', from: l(filter_form.start_date), to: l(filter_form.end_date))
  end

  def fleet_productivity_period_presets
    FleetProductivityFilterForm::PERIOD_PRESETS
  end

  def fleet_productivity_period_preset_label(preset)
    t(preset, scope: 'fleet_productivities.period_presets')
  end

  def fleet_productivity_period_preset_path(preset)
    period = FleetProductivityFilterForm.preset_period(preset)

    fleet_productivity_path(**request.query_parameters.symbolize_keys.except(:empty_routes_page, :empty_regions_page),
                            start_date: period.first, end_date: period.last)
  end

  def fleet_productivity_period_preset_link_class(preset, filter_form)
    variation = FleetProductivityFilterForm.preset_period(preset) == filter_form.period ? 'btn-primary' : 'btn-outline-secondary'

    "btn btn-sm #{variation}"
  end

  def fleet_productivity_customer_group_options(customer_groups)
    customer_groups.map { |customer_group| [customer_group.name, customer_group.id] }
  end

  def fleet_productivity_km(distance)
    distance ? t('fleet_productivities.km', distance: number_with_delimiter(distance.round)) : t('tax.blank')
  end

  def fleet_productivity_routes_chart_card(dashboard)
    return if dashboard.empty?

    tag.div(class: 'mb-4', id: 'fleet_productivity_routes_chart') do
      render('freight_billings/chart_card', title: t('fleet_productivities.show.chart_title'), subtitle: t('fleet_productivities.show.chart_subtitle'),
                                            chart: fleet_productivity_routes_chart(dashboard.routes_chart_data))
    end
  end

  def fleet_productivity_xlsx_sheets(dashboard)
    [fleet_productivity_xlsx_sheet(t('fleet_productivities.show.routes_title'), :route, dashboard.routes),
     fleet_productivity_xlsx_sheet(t('fleet_productivities.show.regions_title'), :region, dashboard.unloading_regions)]
  end

  private

  def fleet_productivity_xlsx_sheet(name, label_column, rankings)
    columns = [xlsx_field(t(label_column, scope: 'fleet_productivities.columns'), &:label),
               xlsx_field(t('fleet_productivities.columns.legs_count'), :integer, &:legs_count),
               xlsx_field(t('fleet_productivities.columns.average_km'), :decimal, &:average_km),
               xlsx_field(t('fleet_productivities.columns.total_km'), :decimal, &:total_km)]

    Export::Sheet.new(name:, columns:, rows: rankings)
  end

  def fleet_productivity_routes_chart(data)
    bar_chart(data.map { |serie| serie.merge(color: BRAND_BLUE, dataset: { backgroundColor: BRAND_BLUE, borderWidth: 0, borderRadius: 4, maxBarThickness: 28 }) },
              height: "#{[data.first[:data].size * RANKING_BAR_HEIGHT, RANKING_MIN_HEIGHT].max}px",
              legend: false,
              suffix: " #{t('fleet_productivities.km_unit')}",
              thousands: t('number.format.delimiter'),
              round: 0,
              library: chart_bar_library(:y).deep_merge(plugins: { datalabels: RANKING_BAR_LABELS }))
  end
end
