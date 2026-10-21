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

  def freight_expense_detail(freight_expense)
    return freight_expense_tonnage_rate(freight_expense.tonnage_rate) if freight_expense.tonnage?
    return freight_expense_insurance(freight_expense) if freight_expense.insurance?
    return t('freight_expenses.tarp_lining_detail') if freight_expense.tarp_lining?

    freight_expense_rule(freight_expense)
  end

  def freight_expense_rule(freight_expense)
    rule = freight_expense.commission_rule
    return t('tax.blank') unless rule
    return rule.name unless can?(:read, :commission_rules)

    link_to rule.name, commission_rule_path(rule), class: 'text-decoration-none'
  end

  def freight_expense_tonnage_rate(tonnage_rate)
    return t('tax.blank') unless tonnage_rate
    return tonnage_rate_label(tonnage_rate) unless can?(:read, :tonnage_rates)

    link_to tonnage_rate_label(tonnage_rate), tonnage_rate_path(tonnage_rate), class: 'text-decoration-none'
  end

  def freight_expense_insurance_rate(insurance_rate)
    return t('tax.blank') unless insurance_rate
    return insurance_rate_label unless can?(:read, :insurance_rates)

    link_to insurance_rate_label, insurance_rate_path, class: 'text-decoration-none'
  end

  def freight_expense_insurance(freight_expense)
    rate = freight_expense_insurance_rate(freight_expense.insurance_rate)
    return rate unless freight_expense.iof_cents.positive?

    t('freight_expenses.insurance_detail_html', rate:, iof: tax_money(freight_expense.iof))
  end

  def freight_expense_base(freight_expense)
    return tonnage_weight(freight_expense.weight_tons) if freight_expense.tonnage?
    return t('tax.blank') if freight_expense.tarp_lining?

    tax_money(freight_expense.base)
  end

  def freight_expense_icms(freight_expense)
    return t('tax.blank') unless freight_expense.commission?

    tax_money(freight_expense.icms)
  end

  def freight_expense_rate(freight_expense)
    return tonnage_rate_per_ton(freight_expense.rate) if freight_expense.tonnage?
    return insurance_percentage(freight_expense.percentage) if freight_expense.insurance?
    return t('freight_expenses.per_transport_document', rate: tax_money(freight_expense.rate)) if freight_expense.tarp_lining?

    commission_percentage(freight_expense.percentage)
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

  def freight_expense_missing_weight_alert(transport_documents)
    return if transport_documents.none?

    render 'freight_expenses/missing_weight_alert', transport_documents:
  end

  def freight_expense_outdated_alert(tonnage_rates)
    return if tonnage_rates.none?

    render 'freight_expenses/outdated_alert', tonnage_rates:
  end

  def freight_expense_missing_insurance_rate_alert(insurance_rate)
    return if insurance_rate

    render 'freight_expenses/missing_insurance_rate_alert'
  end

  def net_freight_card(net_freight, id:)
    return if net_freight.nil?

    render 'freight_expenses/net_freight', net_freight:, id:
  end

  def net_freight_toll_outside_freight(net_freight)
    return unless net_freight.toll_outside_freight.positive?

    safe_join([
                content_tag(:dt, t('freight_expenses.net_freight.toll_outside_freight'), class: 'col-12 col-md-6 text-body-secondary'),
                content_tag(:dd, tax_money(net_freight.toll_outside_freight), class: 'col-12 col-md-6 text-md-end text-body-secondary'),
              ])
  end

  private

  def freight_expense_transport_document_menu(freight_expense)
    Menu.new(name: :show, record: freight_expense.transport_document,
             url: transport_document_path(freight_expense.transport_document), icon: :eye)
  end
end
