module TruckGroupsHelper
  def truck_groups_menu(truck_group)
    menus = []

    menus << truck_group_show_menu(truck_group) if can?(:read, :truck_groups)
    menus << truck_group_edit_menu(truck_group) if can?(:update, :truck_groups)
    menus << truck_group_destroy_menu(truck_group) if can?(:destroy, :truck_groups)

    menus
  end

  def truck_group_status_badge(truck_group)
    return status_badge(t('truck_groups.index.active'), kind: :success) if truck_group.activated?

    status_badge(t('truck_groups.index.deactivated'), kind: :danger)
  end

  def truck_group_axles(truck_group)
    return t('truck_groups.remaining_axles') if truck_group.remaining_axles?
    return t('tax.blank') if truck_group.axles.empty?

    t('truck_groups.axles', count: truck_group.axles.max, axles: truck_group.axles.to_sentence)
  end

  def truck_group_plates(truck_group)
    truck_group.plates.any? ? truck_group.plates.to_sentence : t('tax.blank')
  end

  def truck_group_fuel_percentage(percentage)
    number_to_percentage(percentage, precision: 4, strip_insignificant_zeros: true)
  end

  def truck_group_axle_options
    TruckGroup::AXLE_OPTIONS.map { |axles| [t('truck_groups.axles', count: axles, axles:), axles] }
  end

  def truck_group_form_url(truck_group_form)
    truck_group_form.persisted? ? truck_group_path(truck_group_form.truck_group) : truck_groups_path
  end

  def truck_group_form_submit_label(truck_group_form)
    t("helpers.submit.truck_group.#{truck_group_form.persisted? ? :update : :create}")
  end

  def truck_group_create_button
    create_button(t('truck_groups.index.new_truck_group')) if can?(:create, :truck_groups)
  end

  def truck_group_edit_button(truck_group)
    return unless can?(:update, :truck_groups)

    link_to edit_truck_group_path(truck_group), class: 'btn btn-outline-secondary btn-round' do
      concat icon(:pencil, class: 'me-2')
      concat t('truck_groups.show.edit')
    end
  end

  private

  def truck_group_show_menu(truck_group)
    Menu.new(name: :show, record: truck_group, url: truck_group_path(truck_group), icon: :eye)
  end

  def truck_group_edit_menu(truck_group)
    Menu.new(name: :edit, record: truck_group, url: edit_truck_group_path(truck_group), icon: :pencil)
  end

  def truck_group_destroy_menu(truck_group)
    Menu.new(
      name: :destroy,
      record: truck_group,
      url: truck_group_path(truck_group),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('truck_groups.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
