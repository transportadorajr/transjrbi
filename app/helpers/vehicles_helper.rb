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

  def vehicle_empty_legs_table(empty_legs, total)
    return content_tag(:p, t('vehicles.show.no_empty_legs'), class: 'text-body-secondary mb-0') if empty_legs.none?

    render 'vehicles/empty_legs/table', empty_legs:, total:
  end

  private

  def vehicle_show_menu(vehicle)
    Menu.new(name: :show, record: vehicle, url: vehicle_path(vehicle), icon: :eye)
  end
end
