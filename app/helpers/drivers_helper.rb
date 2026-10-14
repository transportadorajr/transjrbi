module DriversHelper
  def drivers_menu(driver)
    menus = []

    menus << driver_show_menu(driver) if can?(:read, :drivers)

    menus
  end

  def driver_dom_id(driver)
    "driver_#{driver.driver_code}"
  end

  def driver_vehicles_table(vehicles)
    return render('shared/no_content') if vehicles.none?

    render 'drivers/vehicles/table', vehicles:
  end

  def driver_vehicle_plate(vehicle)
    return tax_value(vehicle.plate) unless can?(:read, :vehicles)

    link_to tax_value(vehicle.plate), vehicle_path(vehicle), class: 'fw-semibold text-decoration-none'
  end

  def driver_transport_documents_table(transport_documents)
    return render('shared/no_content') if transport_documents.none?

    render 'drivers/transport_documents/table', transport_documents:
  end

  def driver_transport_document_number(transport_document)
    return transport_document.number unless can?(:read, :transport_documents)

    link_to transport_document.number, transport_document_path(transport_document), class: 'fw-semibold text-decoration-none'
  end

  private

  def driver_show_menu(driver)
    Menu.new(name: :show, record: driver, url: driver_path(driver.driver_code), icon: :eye)
  end
end
