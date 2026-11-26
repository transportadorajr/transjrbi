module CustomersHelper
  def customers_menu(customer)
    menus = []

    menus << customer_show_menu(customer) if can?(:read, :customers)

    menus
  end

  def customer_address(customer)
    tax_list([customer.street, customer.complement, customer.district])
  end

  def customer_emails(customer)
    tax_list(customer.emails)
  end

  def customer_group_name(customer)
    tax_value(customer.customer_group&.name)
  end

  def customer_country(customer)
    country = tax_value(customer.country_type && customer.country_type_name)
    origin = t(customer.country_edited_at ? 'edited_country' : 'automatic_country', scope: 'customers.show')

    safe_join([country, content_tag(:small, origin, class: 'd-block text-muted')], ' ')
  end

  def customer_country_options
    Atua::Customer.enum_options_for_select(:country_type)
  end

  def customer_country_hint(customer)
    return t('customer_countries.form.edited_hint') if customer.country_edited_at

    t('customer_countries.form.automatic_hint', country: tax_value(customer.country_type && customer.country_type_name))
  end

  def customer_edit_country_button(customer)
    return unless can?(:update, :customers)

    link_to edit_customer_country_path(customer), class: 'btn btn-outline-secondary btn-round' do
      concat icon(:pencil, class: 'me-2')
      concat t('customers.show.edit_country')
    end
  end

  def customer_edit_group_button(customer)
    return unless can?(:update, :customers)

    link_to edit_customer_customer_group_path(customer), class: 'btn btn-outline-secondary btn-round' do
      concat icon(:people, class: 'me-2')
      concat t('customers.show.edit_customer_group')
    end
  end

  def customer_group_filter_options(customer_groups)
    [[t('customers.filters.ungrouped'), Atua::Customer::UNGROUPED], *customer_groups.map { |group| [group.name, group.id] }]
  end

  def customers_ungrouped_alert(count)
    return unless count.positive?

    render 'customers/ungrouped_alert', count:
  end

  def customers_pdf_report(customers)
    PdfReport.new(
      title: t('customers.index.pdf.header'),
      columns: [pdf_column(Atua::Customer.human_attribute_name(:name), '2fr'), pdf_column(Atua::Customer.human_attribute_name(:trade_name), '2fr'),
                pdf_column(Atua::Customer.human_attribute_name(:customer_group), '1.5fr'), pdf_column(Atua::Customer.human_attribute_name(:document)),
                pdf_column(Atua::Customer.human_attribute_name(:city), '1.5fr'), pdf_column(Atua::Customer.human_attribute_name(:activity), '2fr')],
      rows: customers.map do |customer|
        [tax_value(customer.name), tax_value(customer.trade_name), customer_group_name(customer), tax_value(customer.document),
         tax_city(customer.city, customer.state), tax_value(customer.activity)]
      end,
    )
  end

  private

  def customer_show_menu(customer)
    Menu.new(name: :show, record: customer, url: customer_path(customer), icon: :eye)
  end
end
