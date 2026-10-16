module FreightExpensesHelper
  def freight_expenses_menu(freight_expense)
    menus = []

    menus << freight_expense_transport_document_menu(freight_expense) if can?(:read, :transport_documents)

    menus
  end

  def freight_expense_transport_document(transport_document)
    return transport_document.number unless can?(:read, :transport_documents)

    link_to transport_document.number, transport_document_path(transport_document), class: 'fw-semibold text-decoration-none'
  end

  def freight_expense_rule(freight_expense)
    rule = freight_expense.commission_rule
    return t('tax.blank') unless rule
    return rule.name unless can?(:read, :commission_rules)

    link_to rule.name, commission_rule_path(rule), class: 'text-decoration-none'
  end

  def freight_expense_recalculate_button
    return unless can?(:update, :commission_rules)

    button_to recalculate_freight_expenses_path, class: 'btn btn-outline-primary btn-round', form_class: 'd-inline-block',
                                                 data: { turbo_confirm: t('freight_expenses.index.confirm_recalculate') } do
      concat icon(:'arrow-repeat', class: 'me-2')
      concat t('freight_expenses.index.recalculate')
    end
  end

  def freight_expense_unmatched_alert(transport_documents)
    return if transport_documents.none?

    render 'freight_expenses/unmatched_alert', transport_documents:
  end

  def net_freight_card(net_freight, id:)
    return if net_freight.nil?

    render 'freight_expenses/net_freight', net_freight:, id:
  end

  private

  def freight_expense_transport_document_menu(freight_expense)
    Menu.new(name: :show, record: freight_expense.transport_document,
             url: transport_document_path(freight_expense.transport_document), icon: :eye)
  end
end
