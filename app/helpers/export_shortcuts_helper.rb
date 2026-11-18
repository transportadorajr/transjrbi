module ExportShortcutsHelper
  def export_shortcuts_menu(export_shortcut)
    menus = []

    menus << export_shortcut_show_menu(export_shortcut) if can?(:read, :export_shortcuts)
    menus << export_shortcut_edit_menu(export_shortcut) if can?(:update, :export_shortcuts)
    menus << activation_menu(export_shortcut, active: export_shortcut.activated?) if can?(:update, :export_shortcuts)
    menus << export_shortcut_destroy_menu(export_shortcut) if can?(:destroy, :export_shortcuts)

    menus
  end

  def export_shortcut_status_badge(export_shortcut)
    return status_badge(t('export_shortcuts.index.active'), kind: :success) if export_shortcut.activated?

    status_badge(t('export_shortcuts.index.deactivated'), kind: :danger)
  end

  def export_shortcut_customer_group(export_shortcut)
    export_shortcut.customer_group&.name || t('export_shortcuts.show.any_customer_group')
  end

  def export_shortcut_plants(export_shortcut)
    names = export_shortcut.export_plants.map(&:name)

    names.any? ? names.join(', ') : t('export_shortcuts.show.any_plant')
  end

  def export_shortcut_countries(export_shortcut)
    return t('export_shortcuts.show.any_country') if export_shortcut.countries.empty?

    export_shortcut.countries.map { |country| export_shortcut_country_name(country) }.join(', ')
  end

  def export_shortcut_country_options
    ExportShortcut::COUNTRIES.map { |country| [export_shortcut_country_name(country), country] }
  end

  def export_shortcut_plant_options(export_shortcut_form)
    export_shortcut_form.export_plants.map { |plant| ["#{plant.name} (#{plant.customer_group.name})", plant.id] }
  end

  def export_shortcut_form_url(export_shortcut_form)
    export_shortcut_form.persisted? ? export_shortcut_path(export_shortcut_form.export_shortcut) : export_shortcuts_path
  end

  def export_shortcut_form_submit_label(export_shortcut_form)
    t("helpers.submit.export_shortcut.#{export_shortcut_form.persisted? ? :update : :create}")
  end

  def export_shortcut_create_button
    create_button(t('export_shortcuts.index.new_export_shortcut')) if can?(:create, :export_shortcuts)
  end

  def export_shortcut_edit_button(export_shortcut)
    return unless can?(:update, :export_shortcuts)

    link_to edit_export_shortcut_path(export_shortcut), class: 'btn btn-outline-secondary btn-round' do
      concat icon(:pencil, class: 'me-2')
      concat t('export_shortcuts.show.edit')
    end
  end

  def export_shortcut_summary_button(export_shortcut)
    return unless can?(:read, :export_summary)

    link_to export_summary_path(shortcut_id: export_shortcut.id), class: 'btn btn-outline-secondary btn-round' do
      concat icon(:'bar-chart-line', class: 'me-2')
      concat t('export_shortcuts.show.open_summary')
    end
  end

  def export_shortcuts_pdf_report(export_shortcuts)
    PdfReport.new(
      title: t('export_shortcuts.index.pdf.header'),
      columns: [pdf_column(ExportShortcut.human_attribute_name(:name), '2fr'), pdf_column(ExportShortcut.human_attribute_name(:customer_group), '1.5fr'),
                pdf_column(ExportShortcut.human_attribute_name(:export_plants), '2fr'), pdf_column(ExportShortcut.human_attribute_name(:countries), '1.5fr'),
                pdf_column(ExportShortcut.human_attribute_name(:status))],
      rows: export_shortcuts.map do |export_shortcut|
        [export_shortcut.name, export_shortcut_customer_group(export_shortcut), export_shortcut_plants(export_shortcut),
         export_shortcut_countries(export_shortcut), export_shortcut_status_badge(export_shortcut)]
      end,
    )
  end

  private

  def export_shortcut_country_name(country)
    country == Dashboard::ExportFacts::UNKNOWN_COUNTRY ? t('dashboards.export.unknown_country') : Atua::Customer.human_enum_name(:country_type, country)
  end

  def export_shortcut_show_menu(export_shortcut)
    Menu.new(name: :show, record: export_shortcut, url: export_shortcut_path(export_shortcut), icon: :eye)
  end

  def export_shortcut_edit_menu(export_shortcut)
    Menu.new(name: :edit, record: export_shortcut, url: edit_export_shortcut_path(export_shortcut), icon: :pencil)
  end

  def export_shortcut_destroy_menu(export_shortcut)
    Menu.new(
      name: :destroy,
      record: export_shortcut,
      url: export_shortcut_path(export_shortcut),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('export_shortcuts.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
