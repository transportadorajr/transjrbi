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

    macro_region.cities.join(', ')
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

  private

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
