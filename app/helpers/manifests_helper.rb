module ManifestsHelper
  def manifests_menu(manifest)
    menus = []

    menus << manifest_show_menu(manifest) if can?(:read, :manifests)

    menus
  end

  def manifest_sort_columns
    [[Atua::Manifest.human_attribute_name(:total_freight), :gross, :desc]]
  end

  def manifest_cities(cities)
    return t('tax.blank') if cities.empty?

    safe_join(cities.map { |(city, state)| content_tag(:span, tax_city(city, state), class: 'd-block') }, ' ')
  end

  def manifest_documents_table(documents)
    return render('shared/no_content') if documents.none?

    render 'manifests/documents/table', documents:
  end

  def manifest_document_number(document)
    transport_document = document.transport_document
    return document.transport_document_number unless transport_document&.active? && can?(:read, :transport_documents)

    link_to document.transport_document_number, transport_document_path(transport_document), class: 'fw-semibold text-decoration-none'
  end

  def manifest_document_toll(document)
    return t('tax.blank') unless document.transport_document

    transport_document_toll(document.transport_document)
  end

  def manifest_document_route(document)
    t('transport_documents.route', origin: tax_city(document.origin_city, document.origin_state),
                                   destination: tax_city(document.destination_city, document.destination_state))
  end

  def manifest_empty_leg_details(empty_leg)
    return content_tag(:p, t('manifests.show.no_empty_leg'), class: 'text-body-secondary mb-0') unless empty_leg

    render 'manifests/empty_leg', empty_leg:
  end

  def manifest_expenses(trip_expenses)
    return if trip_expenses.nil?

    render 'manifests/expenses/card', trip_expenses:
  end

  def manifest_expenses_table(trip_expenses)
    return content_tag(:p, t('manifests.show.no_expenses'), class: 'text-body-secondary mb-0') if trip_expenses.items.empty?

    render 'manifests/expenses/table', trip_expenses:
  end

  def manifest_expense_name(item)
    case item.kind
    when :expense then expense_link(item.record)
    when :toll then t(item.record.toll_voucher_paid.positive? ? 'toll_voucher' : 'toll_in_freight', scope: 'manifests.expenses')
    else item.record.kind_type_name
    end
  end

  def manifest_expense_kind(item)
    t(item.kind, scope: 'manifests.expenses.kinds')
  end

  def manifest_expense_detail(item)
    case item.kind
    when :expense then tax_value(item.record.payee_name)
    when :toll then t('tax.blank')
    else manifest_freight_expense_detail(item.record)
    end
  end

  private

  def manifest_freight_expense_detail(freight_expense)
    parts = [freight_expense_detail(freight_expense), freight_expense_base(freight_expense), freight_expense_rate(freight_expense)]

    safe_join(parts.reject { |part| part == t('tax.blank') }, ' · ')
  end

  def manifest_show_menu(manifest)
    Menu.new(name: :show, record: manifest, url: manifest_path(manifest), icon: :eye)
  end
end
