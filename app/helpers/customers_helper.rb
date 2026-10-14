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

  private

  def customer_show_menu(customer)
    Menu.new(name: :show, record: customer, url: customer_path(customer), icon: :eye)
  end
end
