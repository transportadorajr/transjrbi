class TripsController < BaseController
  include ProductOptions

  has_scope :by_plate, as: :plate
  has_scope :by_driver, as: :driver_code
  has_scope :by_product_group, as: :product_group_id
  has_scope :by_product, as: :product_id

  DETAIL_PARAM = 'detail'.freeze

  before_action :require_trips_dashboard
  before_action :load_dashboard, except: :product_options

  def index
    @detail_row = opened_detail_row
    @rows = listing_page(@dashboard.sorted_rows(params[:sort], params[:direction]))
    @highlights = @dashboard.highlights(params[:sort])

    respond_with_listing(orientation: :landscape)
  end

  def detail
    @row = @dashboard.find_row(params[:key])
    return redirect_to(trips_path(filter_params), alert: t('.row_not_found')) unless @row

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to trips_path(filter_params.merge(DETAIL_PARAM => @row.key)) }
    end
  end

  def product_options
    authorize!(:read, :trips)

    load_product_options
    render 'product_options/show'
  end

  private

  def load_dashboard
    authorize!(:read, :trips)

    @filter_form = TripFilterForm.new(filter_params)
    return redirect_to(trips_path, alert: @filter_form.errors.full_messages.to_sentence) if @filter_form.invalid?

    load_filter_options
    @dashboard = Dashboard::Trip.new(manifests, dimension: @filter_form.dimension, period: @filter_form.period)
  end

  def opened_detail_row
    key = request.query_parameters.delete(DETAIL_PARAM)

    @dashboard.find_row(key) if request.format.html? && !key.nil?
  end

  def require_trips_dashboard
    raise ActionController::RoutingError, 'Not Found' unless Dashboard::Trip.enabled?(current_tenant)
  end

  def load_filter_options
    @drivers = current_tenant.atua_transport_documents.drivers
    @truck_groups = current_tenant.truck_groups.activated.where(remaining_axles: false).order(:name)
    @product_groups = current_tenant.product_groups.groups.activated.order(:name)
    load_product_options
    @last_synced_at = current_tenant.atua_imports.succeeded.maximum(:finished_at)
  end

  def manifests
    manifests = apply_scopes(current_tenant.atua_manifests)
    truck_group_id = @filter_form.truck_group_id
    return manifests if truck_group_id.blank?

    truck_group = @truck_groups.find_by(id: truck_group_id)
    truck_group ? manifests.by_truck_group(truck_group, @truck_groups.flat_map(&:plates)) : manifests.none
  end

  def filter_params
    params.permit(:start_date, :end_date, :dimension, :plate, :driver_code, :truck_group_id, :product_group_id, :product_id)
  end
end
