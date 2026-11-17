module MaintenanceCatalogHelper
  def maintenance_parts_menu(part)
    menus = []

    menus << Menu.new(name: :edit, record: part, url: edit_maintenance_part_path(part), icon: :pencil) if can?(:update, :maintenance_parts)
    menus << Menu.new(name: :movements, record: part, url: maintenance_part_movements_path(maintenance_part_id: part.id), icon: :'box-seam')

    menus
  end

  def maintenance_services_menu(service)
    menus = []

    menus << Menu.new(name: :edit, record: service, url: edit_maintenance_service_path(service), icon: :pencil) if can?(:update, :maintenance_services)

    menus
  end

  def maintenance_part_create_button
    create_button(t('maintenance_parts.index.new_item')) if can?(:create, :maintenance_parts)
  end

  def maintenance_service_create_button
    create_button(t('maintenance_services.index.new_item')) if can?(:create, :maintenance_services)
  end

  def maintenance_part_form_url(item_form)
    item_form.persisted? ? maintenance_part_path(item_form.item) : maintenance_parts_path
  end

  def maintenance_service_form_url(item_form)
    item_form.persisted? ? maintenance_service_path(item_form.item) : maintenance_services_path
  end

  def maintenance_part_sort_columns
    [[MaintenancePart.human_attribute_name(:description), :description], [MaintenancePart.human_attribute_name(:code), :code],
     [MaintenancePart.human_attribute_name(:unit_price), :unit_price, :desc]]
  end

  def maintenance_service_sort_columns
    [[MaintenanceService.human_attribute_name(:description), :description], [MaintenanceService.human_attribute_name(:code), :code],
     [MaintenanceService.human_attribute_name(:price), :price, :desc]]
  end

  def maintenance_catalog_submit_label(item_form)
    t("helpers.submit.maintenance_catalog.#{item_form.persisted? ? :update : :create}")
  end

  def maintenance_catalog_status_badge(item)
    if item.active?
      status_badge(t('maintenance_catalog.status.active'), kind: :success)
    else
      status_badge(t('maintenance_catalog.status.inactive'), kind: :danger)
    end
  end

  def maintenance_catalog_options(items)
    items.map { |item| [item.label, item.id.to_s] }
  end

  def maintenance_order_part_catalog(item_form)
    item_form.maintenance_parts.to_h do |part|
      [part.id.to_s, { code: part.code, description: part.description, unit: part.unit,
                       unit_price: MaintenanceOrderPartForm.format_cents(part.unit_price_cents) }]
    end
  end

  def maintenance_order_service_catalog(item_form)
    item_form.maintenance_services.to_h do |service|
      [service.id.to_s, { description: service.description,
                          price: (MaintenanceOrderServiceForm.format_cents(service.price_cents) if service.price_cents.positive?) }]
    end
  end

  def maintenance_catalog_value(value)
    value.presence || t('tax.blank')
  end
end
