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
