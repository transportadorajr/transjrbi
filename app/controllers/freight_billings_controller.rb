class FreightBillingsController < BaseController
  has_scope :by_plate, as: :plate
  has_scope :by_driver, as: :driver_code
  has_scope :by_customer_group, as: :customer_group_id
  has_scope :by_origin_macro_region, as: :macro_region_id

  before_action :load_dashboard

  def show
    @drivers = current_tenant.atua_transport_documents.drivers
    @customer_groups = current_tenant.customer_groups.order(:name)
    @macro_regions = current_tenant.macro_regions.order(:name)
    @last_synced_at = current_tenant.atua_imports.succeeded.maximum(:finished_at)
    @rows = Kaminari.paginate_array(@dashboard.sorted_rows(params[:sort], params[:direction])).page(params[:page])
  end

  def detail
    @row = @dashboard.row_for(params[:key])

    redirect_to(freight_billing_path(filter_params), alert: t('.row_not_found')) unless @row
  end

  private

  def load_dashboard
    authorize!(:read, :freight_billing)

    @filter_form = FreightBillingFilterForm.new(filter_params)
    return redirect_to(freight_billing_path, alert: @filter_form.errors.full_messages.to_sentence) if @filter_form.invalid?

    @truck_groups = current_tenant.truck_groups.activated.order(:name)
    @dashboard = Dashboard::Freight.new(documents,
                                        manifests: current_tenant.atua_manifests,
                                        dimension: @filter_form.dimension,
                                        period: @filter_form.period)
  end

  def documents
    documents = apply_scopes(current_tenant.atua_transport_documents).without_issuers(current_tenant.excluded_issuers.select(:code))
    truck_group_id = @filter_form.truck_group_id
    return documents if truck_group_id.blank?

    grouped_plates = @truck_groups.flat_map(&:plates)
    return documents.without_axles(@truck_groups.flat_map(&:axles)).without_plates(grouped_plates) if remaining_axles?(truck_group_id)

    truck_group = @truck_groups.find_by(id: truck_group_id)
    truck_group ? documents.by_truck_group(truck_group, grouped_plates) : documents.none
  end

  def remaining_axles?(truck_group_id)
    truck_group_id == TruckGroup::NONE || @truck_groups.exists?(id: truck_group_id, remaining_axles: true)
  end

  def filter_params
    params.permit(:start_date, :end_date, :dimension, :plate, :driver_code, :customer_group_id, :macro_region_id, :truck_group_id)
  end
end
