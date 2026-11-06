module DriversHelper
  def drivers_menu(driver)
    menus = []

    menus << driver_show_menu(driver) if can?(:read, :drivers)
    menus << driver_edit_menu(driver) if can?(:update, :drivers)
    menus << driver_destroy_menu(driver) if can?(:destroy, :drivers)

    menus
  end

  def driver_dom_id(driver)
    "driver_#{driver.driver_code}"
  end

  def driver_edit_button(driver)
    return unless can?(:update, :drivers)

    link_to edit_driver_path(driver.driver_code), class: 'btn btn-outline-secondary btn-round' do
      concat icon(:pencil, class: 'me-2')
      concat t('drivers.show.edit')
    end
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

  def drivers_pdf_report(drivers)
    PdfReport.new(
      title: t('drivers.index.pdf.header'),
      columns: [pdf_column(Atua::Vehicle.human_attribute_name(:driver_name), '2fr'), pdf_column(Atua::Vehicle.human_attribute_name(:driver_code)),
                pdf_column(Atua::Vehicle.human_attribute_name(:display_name), '2fr'), pdf_column(Atua::Vehicle.human_attribute_name(:driver_document)),
                pdf_column(Atua::Vehicle.human_attribute_name(:driver_license)), pdf_column(Atua::Vehicle.human_attribute_name(:plates), '2fr')],
      rows: drivers.map do |driver|
        [tax_value(driver.driver_name), driver.driver_code, tax_value(driver.display_name), tax_value(driver.driver_document),
         tax_value(driver.driver_license), tax_value(driver.plates)]
      end,
    )
  end

  private

  def driver_show_menu(driver)
    Menu.new(name: :show, record: driver, url: driver_path(driver.driver_code), icon: :eye)
  end

  def driver_edit_menu(driver)
    Menu.new(name: :edit, record: driver, url: edit_driver_path(driver.driver_code), icon: :pencil)
  end

  def driver_destroy_menu(driver)
    Menu.new(
      name: :destroy,
      record: driver,
      url: driver_path(driver.driver_code),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('drivers.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
