class MaintenanceOrderPartsController < BaseController
  include MaintenanceOrderItems

  private

  def item_form_class
    MaintenanceOrderPartForm
  end

  def item_scope
    @maintenance_order.parts
  end
end
