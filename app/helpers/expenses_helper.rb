module ExpensesHelper
  def expenses_menu(expense)
    menus = []

    menus << expense_show_menu(expense) if can?(:read, :expenses)

    menus
  end

  def expense_document(expense)
    tax_value([expense.document_number, expense.document_series].compact_blank.join('/'))
  end

  def expense_payee(expense)
    return transport_document_party(expense.payee_name, expense.payee_document) unless expense.payee&.active? && can?(:read, :customers)

    link_to expense.payee_name.presence || expense.payee_code, customer_path(expense.payee), class: 'fw-semibold text-decoration-none'
  end

  def expense_plate(expense)
    return tax_value(expense.plate) unless expense.vehicle&.active? && can?(:read, :vehicles)

    link_to expense.plate, vehicle_path(expense.vehicle), class: 'fw-semibold text-decoration-none'
  end

  def expense_driver(expense)
    return tax_value(expense.trip_driver_name) unless expense.trip_driver_code && can?(:read, :drivers)

    link_to expense.trip_driver_name.presence || expense.trip_driver_code, driver_path(expense.trip_driver_code),
            class: 'fw-semibold text-decoration-none'
  end

  def expense_transport_document(expense)
    number = expense.transport_document_number.presence || expense.transport_document_code
    return tax_value(number) unless expense.allocation == 'freight' && can?(:read, :transport_documents)

    link_to number, transport_document_path(expense.cost_object), class: 'fw-semibold text-decoration-none'
  end

  def expense_link(expense)
    link_to tax_value(expense.history_name), expense_path(expense), class: 'fw-semibold text-decoration-none text-body text-break'
  end

  def expense_attachment(expense)
    expense.attachment_at ? t('expenses.attachment.present') : t('expenses.attachment.absent')
  end

  def expense_icms_credit_percentage(expense)
    return t('tax.blank') unless expense.icms_credit_percentage

    number_to_percentage(expense.icms_credit_percentage, precision: 2)
  end

  private

  def expense_show_menu(expense)
    Menu.new(name: :show, record: expense, url: expense_path(expense), icon: :eye)
  end
end
