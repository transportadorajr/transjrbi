module CustomerGroupsHelper
  def customer_groups_menu(customer_group)
    menus = []

    menus << customer_group_show_menu(customer_group) if can?(:read, :customer_groups)
    menus << customer_group_edit_menu(customer_group) if can?(:update, :customer_groups)
    menus << customer_group_destroy_menu(customer_group) if can?(:destroy, :customer_groups)

    menus
  end

  def customer_group_status_badge(customer_group)
    return status_badge(t('customer_groups.index.active'), kind: :success) if customer_group.activated?

    status_badge(t('customer_groups.index.deactivated'), kind: :danger)
  end

  def customer_group_customers_count(customer_group, customer_counts)
    customer_counts.fetch(customer_group.id, 0)
  end

  def customer_group_terms(customer_group)
    customer_group.terms.join(', ').presence || t('customer_groups.show.no_terms')
  end

  def customer_group_form_url(customer_group_form)
    customer_group_form.persisted? ? customer_group_path(customer_group_form.customer_group) : customer_groups_path
  end

  def customer_group_form_submit_label(customer_group_form)
    t("helpers.submit.customer_group.#{customer_group_form.persisted? ? :update : :create}")
  end

  def customer_group_create_button
    create_button(t('customer_groups.index.new_customer_group')) if can?(:create, :customer_groups)
  end

  def customer_group_edit_button(customer_group)
    return unless can?(:update, :customer_groups)

    link_to edit_customer_group_path(customer_group), class: 'btn btn-outline-secondary btn-round' do
      concat icon(:pencil, class: 'me-2')
      concat t('customer_groups.show.edit')
    end
  end

  def customer_group_regroup_button(customer_group)
    return if customer_group.terms.empty? || cannot?(:update, :customer_groups)

    button_to regroup_customer_group_path(customer_group), method: :patch, class: 'btn btn-outline-primary btn-round',
                                                           form_class: 'd-inline-block',
                                                           data: { turbo_confirm: t('customer_groups.show.confirm_regroup') } do
      concat icon(:'arrow-repeat', class: 'me-2')
      concat t('customer_groups.show.regroup')
    end
  end

  def customer_group_customers_table(customers)
    return render('shared/no_content') if customers.none?

    render 'customer_groups/customers_table', collection: customers
  end

  private

  def customer_group_show_menu(customer_group)
    Menu.new(name: :show, record: customer_group, url: customer_group_path(customer_group), icon: :eye)
  end

  def customer_group_edit_menu(customer_group)
    Menu.new(name: :edit, record: customer_group, url: edit_customer_group_path(customer_group), icon: :pencil)
  end

  def customer_group_destroy_menu(customer_group)
    Menu.new(
      name: :destroy,
      record: customer_group,
      url: customer_group_path(customer_group),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('customer_groups.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
