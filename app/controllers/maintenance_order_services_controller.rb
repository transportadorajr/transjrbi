class MaintenanceOrderServicesController < BaseController
  include MaintenanceOrderItems

  private

  def item_form_class
    MaintenanceOrderServiceForm
  end

  def item_scope
    @maintenance_order.services
  end
end
