module ManifestsHelper
  def manifests_menu(manifest)
    menus = []

    menus << manifest_show_menu(manifest) if can?(:read, :manifests)

    menus
  end

  def manifest_sort_columns
    columns = [[Atua::Manifest.human_attribute_name(:gross_per_km), :gross_per_km, :desc]]
    columns << [Atua::Manifest.human_attribute_name(:net_per_km), :net_per_km, :desc] if can?(:read, :freight_expenses)

    columns
  end

  def manifest_net_per_km_header
    return unless can?(:read, :freight_expenses)

    sortable_header(Atua::Manifest.human_attribute_name(:net_per_km), :net_per_km, first_direction: :desc, class: 'd-none d-md-table-cell text-nowrap')
  end

  def manifest_net_per_km_cell(manifest)
    return unless can?(:read, :freight_expenses)

    content_tag(:td, freight_money(manifest.net_per_km_cents), class: 'd-none d-md-table-cell text-nowrap')
  end

  def manifest_mobile_details(manifest)
    details = [[Atua::Manifest.human_attribute_name(:gross_per_km), freight_money(manifest.gross_per_km_cents)]]
    details << [Atua::Manifest.human_attribute_name(:net_per_km), freight_money(manifest.net_per_km_cents)] if can?(:read, :freight_expenses)

    details + [[Atua::Manifest.human_attribute_name(:customer_group), manifest_names(manifest.customer_groups)],
               [Atua::Manifest.human_attribute_name(:origin), manifest_cities(manifest.origins)],
               [Atua::Manifest.human_attribute_name(:destination), manifest_cities(manifest.destinations)]]
  end

  def manifest_cities(cities)
    return t('tax.blank') if cities.empty?

    safe_join(cities.map { |(city, state)| content_tag(:span, tax_city(city, state), class: 'd-block') }, ' ')
  end

  def manifest_names(names)
    return t('tax.blank') if names.empty?

    safe_join(names.map { |name| content_tag(:span, name, class: 'd-block') }, ' ')
  end

  def manifest_documents_table(documents, net_cents_by_document)
    return render('shared/no_content') if documents.none?

    render 'manifests/documents/table', documents:, net_cents_by_document:
  end

  def manifest_document_net_per_km_header(net_cents_by_document)
    return unless net_cents_by_document

    content_tag(:th, Atua::ManifestDocument.human_attribute_name(:net_per_km), class: 'text-nowrap')
  end

  def manifest_document_net_per_km_cell(document, net_cents_by_document)
    return unless net_cents_by_document

    content_tag(:td, tax_money(document.per_km(document.net_cents(net_cents_by_document))), class: 'text-nowrap')
  end

  def manifest_document_number(document)
    transport_document = document.transport_document
    return document.transport_document_number unless transport_document&.active? && can?(:read, :transport_documents)

    link_to document.transport_document_number, transport_document_path(transport_document), class: 'fw-semibold text-decoration-none'
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
    when :complement_credit then manifest_complement_name(:complement_credit, item.record)
    when :complement_transfer then manifest_complement_name(:complement_transfer, item.record.complemented_transport_document)
    when :toll then t(item.record.toll_voucher_paid.positive? ? 'toll_voucher' : 'toll_in_freight', scope: 'manifests.expenses')
    else item.record.kind_type_name
    end
  end

  def manifest_duplicate_expenses_alert(trip_expenses)
    count = trip_expenses.duplicates_count
    return if count.zero?

    content_tag(:div, t('manifests.show.duplicate_alert', count:), class: 'alert alert-warning mb-3', role: :alert, id: 'duplicate_expenses')
  end

  def manifest_expense_row_class(item, trip_expenses)
    'table-warning' if trip_expenses.duplicate?(item)
  end

  def manifest_expense_duplicate_badge(item, trip_expenses)
    return unless trip_expenses.duplicate?(item)

    status_badge(t('manifests.expenses.duplicate'), kind: :warning)
  end

  def manifest_expense_kind(item)
    t(item.kind, scope: 'manifests.expenses.kinds')
  end

  def manifest_expense_detail(item)
    case item.kind
    when :expense then tax_value(item.record.payee_name)
    when :toll, :complement_credit, :complement_transfer then t('tax.blank')
    else manifest_freight_expense_detail(item.record)
    end
  end

  def manifest_expense_amount(item)
    expense_amount(item.amount, credit: item.kind == :complement_credit)
  end

  private

  def manifest_complement_name(kind, transport_document)
    t("#{kind}_html", scope: 'manifests.expenses', number: freight_expense_transport_document(transport_document))
  end

  def manifest_freight_expense_detail(freight_expense)
    parts = [freight_expense_detail(freight_expense), freight_expense_base(freight_expense), freight_expense_rate(freight_expense)]

    safe_join(parts.reject { |part| part == t('tax.blank') }, ' · ')
  end

  def manifest_show_menu(manifest)
    Menu.new(name: :show, record: manifest, url: manifest_path(manifest), icon: :eye)
  end
end
