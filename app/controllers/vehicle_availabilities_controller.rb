class VehicleAvailabilitiesController < BaseController
  include MaintenanceFeature

  has_scope :by_plate, as: :plate
  has_scope :by_fleet_kind, as: :kind
  has_scope :by_availability, as: :availability

  def show
    authorize!(:read, :vehicle_availability)

    fleet = current_tenant.atua_vehicles.active.own_fleet
    @vehicles = listing_page(apply_sort(apply_scopes(fleet), Atua::Vehicle.in_maintenance_first, :plate, :id))
    @pending_orders = pending_orders_by_plate(@vehicles.map(&:plate))
    @total_count = fleet.count
    @in_maintenance_count = fleet.in_maintenance.count
  end

  private

  def pending_orders_by_plate(plates)
    current_tenant.maintenance_orders.pending.where(plate: plates).order(:opened_at, :id).index_by(&:plate)
  end
end
