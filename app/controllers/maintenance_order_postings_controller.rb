class MaintenanceOrderPostingsController < BaseController
  include MaintenanceFeature

  before_action :set_maintenance_order

  def edit
    authorize!(:update, :maintenance_orders)

    @posting_form = MaintenanceOrderPostingForm.for_maintenance_order(@maintenance_order)
    render formats: :turbo_stream
  end

  def update
    authorize!(:update, :maintenance_orders)

    @posting_form = MaintenanceOrderPostingForm.new(maintenance_order: @maintenance_order, posted_by: current_user, **posting_params)

    if @posting_form.save
      redirect_to maintenance_order_path(@maintenance_order), notice: t('.success'), status: :see_other
    else
      render formats: :turbo_stream, status: :unprocessable_content
    end
  end

  private

  def set_maintenance_order
    @maintenance_order = current_tenant.maintenance_orders.find(params.expect(:maintenance_order_id))
  end

  def posting_params
    params.expect(maintenance_order_posting: MaintenanceOrderPostingForm::PERMITTED_ATTRIBUTES)
  end
end
