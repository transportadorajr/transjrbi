class MaintenanceOrderPartsController < BaseController
  include MaintenanceOrderItems

  private

  def item_form_class
    MaintenanceOrderPartForm
  end

  def item_scope
    @maintenance_order.items.maintenance_order_parts
  end

  def find_item(id)
    item_scope.find_by!(itemizable_id: id)
  end
end
