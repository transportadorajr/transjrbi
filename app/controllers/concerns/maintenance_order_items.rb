module MaintenanceOrderItems
  extend ActiveSupport::Concern

  included do
    include MaintenanceFeature

    before_action :set_maintenance_order
    before_action :set_item, only: %i[edit update destroy]
    before_action :require_editable_order
  end

  def new
    authorize!(:update, :maintenance_orders)

    @item_form = item_form_class.new(maintenance_order: @maintenance_order)
    render 'maintenance_order_items/modal', formats: :turbo_stream
  end

  def edit
    authorize!(:update, :maintenance_orders)

    @item_form = item_form_class.for_item(@item)
    render 'maintenance_order_items/modal', formats: :turbo_stream
  end

  def create
    authorize!(:update, :maintenance_orders)

    @item_form = item_form_class.new(maintenance_order: @maintenance_order, **item_params)
    save_item_form
  end

  def update
    authorize!(:update, :maintenance_orders)

    @item_form = item_form_class.for_item(@item)
    @item_form.assign_attributes(item_params)
    save_item_form
  end

  def destroy
    authorize!(:update, :maintenance_orders)

    MaintenanceOrder.transaction do
      @item.destroy!
      MaintenanceOrders::RecalculateTotalsCommand.call(@maintenance_order)
    end

    redirect_to maintenance_order_path(@maintenance_order), notice: t('.success'), status: :see_other
  end

  private

  def save_item_form
    if @item_form.save
      redirect_to maintenance_order_path(@maintenance_order), notice: t('.success'), status: :see_other
    else
      render 'maintenance_order_items/form', formats: :turbo_stream, status: :unprocessable_content
    end
  end

  def require_editable_order
    return if @maintenance_order.editable?

    redirect_to maintenance_order_path(@maintenance_order), alert: t('maintenance_orders.locked'), status: :see_other
  end

  def set_maintenance_order
    @maintenance_order = current_tenant.maintenance_orders.find(params.expect(:maintenance_order_id))
  end

  def set_item
    @item = item_scope.find(params.expect(:id))
  end

  def item_params
    params.expect(item_form_class.model_name.param_key => item_form_class::PERMITTED_ATTRIBUTES)
  end
end
