module VehiclesHelper
  def vehicles_menu(vehicle)
    menus = []

    menus << vehicle_show_menu(vehicle) if can?(:read, :vehicles)

    menus
  end

  def vehicle_description(vehicle)
    tax_value([vehicle.brand, vehicle.model].compact_blank.join(' '))
  end

  def vehicle_years(vehicle)
    tax_value([vehicle.manufacture_year, vehicle.model_year].compact.join('/'))
  end

  def vehicle_driver(vehicle)
    return tax_value(vehicle.driver_name) unless vehicle.driver_code && can?(:read, :drivers)

    link_to vehicle.driver_name.presence || vehicle.driver_code, driver_path(vehicle.driver_code), class: 'fw-semibold text-decoration-none'
  end

  private

  def vehicle_show_menu(vehicle)
    Menu.new(name: :show, record: vehicle, url: vehicle_path(vehicle), icon: :eye)
  end
end
