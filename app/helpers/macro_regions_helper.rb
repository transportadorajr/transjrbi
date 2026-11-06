module MacroRegionsHelper
  def macro_regions_menu(macro_region)
    menus = []

    menus << macro_region_show_menu(macro_region) if can?(:read, :macro_regions)
    menus << macro_region_edit_menu(macro_region) if can?(:update, :macro_regions)
    menus << macro_region_destroy_menu(macro_region) if can?(:destroy, :macro_regions)

    menus
  end

  def macro_region_coverage(macro_region)
    return t('macro_regions.coverage.remaining_state', state: macro_region.state) if macro_region.remaining_state?

    t('macro_regions.coverage.cities', count: macro_region.cities.size)
  end

  def macro_region_cities(macro_region)
    return t('macro_regions.show.remaining_state_cities', state: macro_region.state) if macro_region.remaining_state?

    macro_region.cities.sort_by { |city| I18n.transliterate(city.name) }.map(&:name).join(', ')
  end

  def macro_region_cities_field(form, macro_region_form)
    render 'macro_regions/cities_field', form:, macro_region_form:, options: macro_region_city_options(macro_region_form)
  end

  def macro_region_form_url(macro_region_form)
    macro_region_form.persisted? ? macro_region_path(macro_region_form.macro_region) : macro_regions_path
  end

  def macro_region_form_submit_label(macro_region_form)
    t("helpers.submit.macro_region.#{macro_region_form.persisted? ? :update : :create}")
  end

  def macro_region_create_button
    create_button(t('macro_regions.index.new_macro_region')) if can?(:create, :macro_regions)
  end

  def macro_region_edit_button(macro_region)
    return unless can?(:update, :macro_regions)

    link_to edit_macro_region_path(macro_region), class: 'btn btn-outline-secondary btn-round' do
      concat icon(:pencil, class: 'me-2')
      concat t('macro_regions.show.edit')
    end
  end

  def macro_regions_pdf_report(macro_regions)
    PdfReport.new(
      title: t('macro_regions.index.pdf.header'),
      columns: [pdf_column(MacroRegion.human_attribute_name(:name), '2fr'), pdf_column(MacroRegion.human_attribute_name(:state)),
                pdf_column(MacroRegion.human_attribute_name(:coverage), '3fr')],
      rows: macro_regions.map { |macro_region| [macro_region.name, macro_region.state, macro_region_coverage(macro_region)] },
    )
  end

  private

  def macro_region_city_options(macro_region_form)
    macro_region_form.available_cities.map { |city| [t('tax.city', city: city.name, state: city.state), city.id] }
  end

  def macro_region_show_menu(macro_region)
    Menu.new(name: :show, record: macro_region, url: macro_region_path(macro_region), icon: :eye)
  end

  def macro_region_edit_menu(macro_region)
    Menu.new(name: :edit, record: macro_region, url: edit_macro_region_path(macro_region), icon: :pencil)
  end

  def macro_region_destroy_menu(macro_region)
    Menu.new(
      name: :destroy,
      record: macro_region,
      url: macro_region_path(macro_region),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('macro_regions.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
