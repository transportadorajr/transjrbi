class FreightBillingsController < BaseController
  has_scope :by_plate, as: :plate
  has_scope :by_taker, as: :taker_code
  has_scope :by_driver, as: :driver_code
  has_scope :by_customer_group, as: :customer_group_id
  has_scope :by_origin_macro_region, as: :macro_region_id

  def show
    authorize!(:read, :freight_billing)

    @filter_form = FreightBillingFilterForm.new(filter_params)
    return redirect_to(freight_billing_path, alert: @filter_form.errors.full_messages.to_sentence) if @filter_form.invalid?

    @customers = current_tenant.atua_customers.where(code: current_tenant.atua_transport_documents.select(:taker_code)).order(:name)
    @drivers = current_tenant.atua_transport_documents.drivers
    @customer_groups = current_tenant.customer_groups.order(:name)
    @macro_regions = current_tenant.macro_regions.order(:name)
    @truck_groups = current_tenant.truck_groups.activated.order(:name)
    @dashboard = Dashboard::Freight.new(documents,
                                        manifests: current_tenant.atua_manifests,
                                        dimension: @filter_form.dimension,
                                        period: @filter_form.period)
  end

  private

  def documents
    documents = apply_scopes(current_tenant.atua_transport_documents).without_issuers(current_tenant.excluded_issuers.select(:code))
    truck_group_id = @filter_form.truck_group_id
    return documents if truck_group_id.blank?
    return documents.without_axles(@truck_groups.flat_map(&:axles)) if remaining_axles?(truck_group_id)

    documents.by_axles(@truck_groups.find_by(id: truck_group_id)&.axles.to_a)
  end

  def remaining_axles?(truck_group_id)
    truck_group_id == TruckGroup::NONE || @truck_groups.exists?(id: truck_group_id, remaining_axles: true)
  end

  def filter_params
    params.permit(:start_date, :end_date, :dimension, :plate, :taker_code, :driver_code, :customer_group_id, :macro_region_id, :truck_group_id)
  end
end
