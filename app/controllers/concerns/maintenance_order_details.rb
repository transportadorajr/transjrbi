module MaintenanceOrderDetails
  extend ActiveSupport::Concern

  private

  def load_maintenance_order_details
    @parts = @maintenance_order.items.maintenance_order_parts.preload(:itemizable).ordered
    @mechanics = @maintenance_order.mechanics
    @labors = @maintenance_order.labors.preload(:workshop_employee).order(:worked_on, :start_time, :id)
    @services = @maintenance_order.items.maintenance_order_services.preload(itemizable: :supplier).ordered
    @labor_hours = @labors.sum(:hours)
    @signatures = @maintenance_order.signatures.order(:signer_role_type, :signer_name, :id)
  end
end
