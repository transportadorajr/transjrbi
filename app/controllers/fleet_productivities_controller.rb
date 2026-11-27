class FleetProductivitiesController < BaseController
  def show
    authorize!(:read, :fleet_productivity)

    @filter_form = FleetProductivityFilterForm.new(filter_params)
    return redirect_to(fleet_productivity_path, alert: @filter_form.errors.full_messages.to_sentence) if @filter_form.invalid?

    load_dashboard
    @customer_groups = current_tenant.customer_groups.activated.order(:name)

    respond_with_listing(pdf: false, xlsx: -> { helpers.fleet_productivity_xlsx_sheets(@dashboard) })
  end

  private

  def load_dashboard
    @dashboard = Dashboard::FleetProductivity.new(@filter_form.apply(current_tenant.empty_legs),
                                                  macro_regions: current_tenant.macro_regions.activated.preload(:cities))
    @empty_routes = listing_page(@dashboard.routes, param_name: :empty_routes_page)
    @empty_regions = listing_page(@dashboard.unloading_regions, param_name: :empty_regions_page)
  end

  def filter_params
    params.permit(:start_date, :end_date, :plate, :customer_group_id)
  end
end
