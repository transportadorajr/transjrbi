class FreightBillingsController < BaseController
  has_scope :by_plate, as: :plate
  has_scope :by_customer_group, as: :customer_group_id

  def show
    authorize!(:read, :freight_billing)

    @filter_form = FreightBillingFilterForm.new(filter_params)
    return redirect_to(freight_billing_path, alert: @filter_form.errors.full_messages.to_sentence) if @filter_form.invalid?

    @customer_groups = current_tenant.customer_groups.order(:name)
    @dashboard = Dashboard::Freight.new(apply_scopes(current_tenant.atua_transport_documents),
                                        manifests: current_tenant.atua_manifests,
                                        dimension: @filter_form.dimension,
                                        period: @filter_form.period)
  end

  private

  def filter_params
    params.permit(:start_date, :end_date, :dimension, :plate, :customer_group_id)
  end
end
