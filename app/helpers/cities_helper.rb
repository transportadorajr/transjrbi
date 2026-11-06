module CitiesHelper
  def cities_menu(city)
    menus = []

    menus << city_show_menu(city) if can?(:read, :cities)
    menus << city_edit_menu(city) if can?(:update, :cities)
    menus << city_destroy_menu(city) if can?(:destroy, :cities)

    menus
  end

  def city_macro_region_name(city)
    city.macro_region&.name || t('cities.no_macro_region')
  end

  def city_macro_region_filter_options(macro_regions)
    options = macro_regions.map { |macro_region| [macro_region_label(macro_region), macro_region.id] }

    options_for_select(options + [[t('cities.no_macro_region'), MacroRegion::OTHERS]], params[:macro_region_id])
  end

  def city_macro_region_options(city_form)
    city_form.available_macro_regions.map { |macro_region| [macro_region_label(macro_region), macro_region.id] }
  end

  def city_unassigned_origins_alert(origins)
    return if origins.none?

    render 'cities/unassigned_origins_alert', origins:
  end

  def city_form_url(city_form)
    city_form.persisted? ? city_path(city_form.city) : cities_path
  end

  def city_form_submit_label(city_form)
    t("helpers.submit.city.#{city_form.persisted? ? :update : :create}")
  end

  def city_create_button
    create_button(t('cities.index.new_city')) if can?(:create, :cities)
  end

  def city_edit_button(city)
    return unless can?(:update, :cities)

    link_to edit_city_path(city), class: 'btn btn-outline-secondary btn-round' do
      concat icon(:pencil, class: 'me-2')
      concat t('cities.show.edit')
    end
  end

  def cities_pdf_report(cities)
    PdfReport.new(
      title: t('cities.index.pdf.header'),
      columns: [pdf_column(City.human_attribute_name(:name), '2fr'), pdf_column(City.human_attribute_name(:state)),
                pdf_column(City.human_attribute_name(:macro_region), '2fr')],
      rows: cities.map { |city| [city.name, city.state, city_macro_region_name(city)] },
    )
  end

  private

  def macro_region_label(macro_region)
    t('cities.macro_region_label', name: macro_region.name, state: macro_region.state)
  end

  def city_show_menu(city)
    Menu.new(name: :show, record: city, url: city_path(city), icon: :eye)
  end

  def city_edit_menu(city)
    Menu.new(name: :edit, record: city, url: edit_city_path(city), icon: :pencil)
  end

  def city_destroy_menu(city)
    Menu.new(
      name: :destroy,
      record: city,
      url: city_path(city),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('cities.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
