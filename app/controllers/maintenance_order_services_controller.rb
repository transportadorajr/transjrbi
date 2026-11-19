class MaintenanceOrderServicesController < BaseController
  include MaintenanceOrderItems

  private

  def item_form_class
    MaintenanceOrderServiceForm
  end

  def item_scope
    @maintenance_order.items.maintenance_order_services
  end

  def find_item(id)
    item_scope.find_by!(itemizable_id: id)
  end
end
