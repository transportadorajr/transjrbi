class TripsController < BaseController
  has_scope :by_plate, as: :plate
  has_scope :by_driver, as: :driver_code
  has_scope :by_product_group, as: :product_group_id

  def index
    authorize!(:read, :trips)

    @filter_form = TripFilterForm.new(filter_params)
    return redirect_to(trips_path, alert: @filter_form.errors.full_messages.to_sentence) if @filter_form.invalid?

    load_filter_options
    @dashboard = Dashboard::Trip.new(manifests, dimension: @filter_form.dimension, period: @filter_form.period)
    @rows = Kaminari.paginate_array(@dashboard.sorted_rows(params[:sort], params[:direction])).page(params[:page])
    @highlights = @dashboard.highlights(params[:sort])
  end

  private

  def load_filter_options
    @drivers = current_tenant.atua_transport_documents.drivers
    @truck_groups = current_tenant.truck_groups.activated.where(remaining_axles: false).order(:name)
    @product_groups = current_tenant.product_groups.groups.activated.order(:name)
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
    params.permit(:start_date, :end_date, :dimension, :plate, :driver_code, :truck_group_id, :product_group_id)
  end
end
