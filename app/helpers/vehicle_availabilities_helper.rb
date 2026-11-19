module VehicleAvailabilitiesHelper
  def vehicle_availability_menu(vehicle, maintenance_order)
    menus = []

    menus << vehicle_availability_vehicle_menu(vehicle) if can?(:read, :vehicles)
    menus << vehicle_availability_order_menu(maintenance_order) if maintenance_order

    menus
  end

  def vehicle_availability_badge(maintenance_order)
    return status_badge(t('vehicle_availabilities.availabilities.available'), kind: :success) if maintenance_order.nil?

    status_badge(t('vehicle_availabilities.availabilities.in_maintenance'), kind: :danger)
  end

  def vehicle_availability_kind(vehicle)
    kind = Atua::Vehicle::FLEET_KINDS.key(vehicle.category)

    t(kind, scope: 'vehicle_availabilities.fleet_kind_names')
  end

  def vehicle_availability_order_number(maintenance_order)
    tax_value(maintenance_order&.number)
  end

  def vehicle_availability_order_status(maintenance_order)
    return tax_value(nil) if maintenance_order.nil?

    maintenance_order_status_badge(maintenance_order)
  end

  def vehicle_availability_estimated_completion(maintenance_order)
    return tax_value(nil) if maintenance_order.nil?

    maintenance_order_estimated_completion(maintenance_order)
  end

  def vehicle_availability_stopped(maintenance_order)
    return tax_value(nil) if maintenance_order.nil?

    maintenance_order_vehicle_stopped(maintenance_order)
  end

  def vehicle_availability_filter_options(options, param)
    options_for_select(options, params[param])
  end

  private

  def vehicle_availability_vehicle_menu(vehicle)
    Menu.new(name: :show_vehicle, record: vehicle, url: vehicle_return_path(vehicle), icon: :truck)
  end

  def vehicle_availability_order_menu(maintenance_order)
    Menu.new(name: :show_maintenance_order, record: maintenance_order, icon: :'wrench-adjustable',
             url: vehicle_availability_maintenance_order_path(maintenance_order))
  end
end
