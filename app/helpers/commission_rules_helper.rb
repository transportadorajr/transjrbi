module CommissionRulesHelper
  def commission_rules_menu(commission_rule)
    menus = []

    menus << commission_rule_show_menu(commission_rule) if can?(:read, :commission_rules)
    menus << commission_rule_edit_menu(commission_rule) if can?(:update, :commission_rules)
    menus << commission_rule_destroy_menu(commission_rule) if can?(:destroy, :commission_rules)

    menus
  end

  def commission_rule_status_badge(commission_rule)
    return status_badge(t('commission_rules.index.active'), kind: :success) if commission_rule.activated?

    status_badge(t('commission_rules.index.deactivated'), kind: :danger)
  end

  def commission_percentage(percentage)
    number_to_percentage(percentage, precision: 2)
  end

  def commission_rule_cities(commission_rule)
    return t('commission_rules.show.any_brazilian_state') if commission_rule.national?

    commission_rule.cities.join(', ')
  end

  def commission_rule_form_url(commission_rule_form)
    commission_rule_form.persisted? ? commission_rule_path(commission_rule_form.commission_rule) : commission_rules_path
  end

  def commission_rule_form_submit_label(commission_rule_form)
    t("helpers.submit.commission_rule.#{commission_rule_form.persisted? ? :update : :create}")
  end

  def commission_rule_create_button
    create_button(t('commission_rules.index.new_commission_rule')) if can?(:create, :commission_rules)
  end

  def commission_rule_edit_button(commission_rule)
    return unless can?(:update, :commission_rules)

    link_to edit_commission_rule_path(commission_rule), class: 'btn btn-outline-secondary btn-round' do
      concat icon(:pencil, class: 'me-2')
      concat t('commission_rules.show.edit')
    end
  end

  private

  def commission_rule_show_menu(commission_rule)
    Menu.new(name: :show, record: commission_rule, url: commission_rule_path(commission_rule), icon: :eye)
  end

  def commission_rule_edit_menu(commission_rule)
    Menu.new(name: :edit, record: commission_rule, url: edit_commission_rule_path(commission_rule), icon: :pencil)
  end

  def commission_rule_destroy_menu(commission_rule)
    Menu.new(
      name: :destroy,
      record: commission_rule,
      url: commission_rule_path(commission_rule),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('commission_rules.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
