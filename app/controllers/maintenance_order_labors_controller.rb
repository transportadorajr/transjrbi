class MaintenanceOrderLaborsController < BaseController
  include MaintenanceOrderItems

  private

  def item_form_class
    MaintenanceOrderLaborForm
  end

  def item_scope
    @maintenance_order.labors
  end
end
