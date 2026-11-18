module ExportPlantsHelper
  def export_plants_menu(export_plant)
    menus = []

    menus << export_plant_show_menu(export_plant) if can?(:read, :export_plants)
    menus << export_plant_edit_menu(export_plant) if can?(:update, :export_plants)
    menus << activation_menu(export_plant, active: export_plant.activated?) if can?(:update, :export_plants)
    menus << export_plant_destroy_menu(export_plant) if can?(:destroy, :export_plants)

    menus
  end

  def export_plant_status_badge(export_plant)
    return status_badge(t('export_plants.index.active'), kind: :success) if export_plant.activated?

    status_badge(t('export_plants.index.deactivated'), kind: :danger)
  end

  def export_plant_cities(export_plant)
    export_plant.cities.join(', ')
  end

  def export_plant_form_url(export_plant_form)
    export_plant_form.persisted? ? export_plant_path(export_plant_form.export_plant) : export_plants_path
  end

  def export_plant_form_submit_label(export_plant_form)
    t("helpers.submit.export_plant.#{export_plant_form.persisted? ? :update : :create}")
  end

  def export_plant_create_button
    create_button(t('export_plants.index.new_export_plant')) if can?(:create, :export_plants)
  end

  def export_plant_edit_button(export_plant)
    return unless can?(:update, :export_plants)

    link_to edit_export_plant_path(export_plant), class: 'btn btn-outline-secondary btn-round' do
      concat icon(:pencil, class: 'me-2')
      concat t('export_plants.show.edit')
    end
  end

  def export_plants_pdf_report(export_plants)
    PdfReport.new(
      title: t('export_plants.index.pdf.header'),
      columns: [pdf_column(ExportPlant.human_attribute_name(:name), '1.5fr'), pdf_column(ExportPlant.human_attribute_name(:customer_group), '1.5fr'),
                pdf_column(ExportPlant.human_attribute_name(:cities), '3fr'), pdf_column(ExportPlant.human_attribute_name(:status))],
      rows: export_plants.map do |export_plant|
        [export_plant.name, export_plant.customer_group.name, export_plant_cities(export_plant), export_plant_status_badge(export_plant)]
      end,
    )
  end

  private

  def export_plant_show_menu(export_plant)
    Menu.new(name: :show, record: export_plant, url: export_plant_path(export_plant), icon: :eye)
  end

  def export_plant_edit_menu(export_plant)
    Menu.new(name: :edit, record: export_plant, url: edit_export_plant_path(export_plant), icon: :pencil)
  end

  def export_plant_destroy_menu(export_plant)
    Menu.new(
      name: :destroy,
      record: export_plant,
      url: export_plant_path(export_plant),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('export_plants.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
