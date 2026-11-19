class VehicleAvailabilityOrdersController < BaseController
  include MaintenanceFeature
  include MaintenanceOrderDetails

  def show
    authorize!(:read, :vehicle_availability)

    @maintenance_order = unavailable_vehicle_orders.find(params.expect(:id))
    load_maintenance_order_details
  end

  private

  def current_ability
    @current_ability ||= Ability.new(current_user, resources: Ability.resources_outside_maintenance)
  end

  def unavailable_vehicle_orders
    current_tenant.maintenance_orders.pending.where(plate: current_tenant.atua_vehicles.active.own_fleet.select(:plate))
  end
end
