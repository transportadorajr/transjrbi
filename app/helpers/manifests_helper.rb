module ManifestsHelper
  def manifests_menu(manifest)
    menus = []

    menus << manifest_show_menu(manifest) if can?(:read, :manifests)

    menus
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

  def manifest_document_route(document)
    t('transport_documents.route', origin: tax_city(document.origin_city, document.origin_state),
                                   destination: tax_city(document.destination_city, document.destination_state))
  end

  def manifest_empty_leg_details(empty_leg)
    return content_tag(:p, t('manifests.show.no_empty_leg'), class: 'text-body-secondary mb-0') unless empty_leg

    render 'manifests/empty_leg', empty_leg:
  end

  def manifest_expenses(expenses, total)
    return if expenses.nil?

    render 'manifests/expenses/card', expenses:, total:
  end

  def manifest_expenses_table(expenses, total)
    return content_tag(:p, t('manifests.show.no_expenses'), class: 'text-body-secondary mb-0') if expenses.none?

    render 'manifests/expenses/table', expenses:, total:
  end

  def manifest_freight_expenses(freight_expenses, total)
    return if freight_expenses.blank?

    render 'manifests/freight_expenses/card', freight_expenses:, total:
  end

  def manifest_expense_transport_document(expense)
    transport_document = expense.cost_object
    return transport_document.number unless can?(:read, :transport_documents)

    link_to transport_document.number, transport_document_path(transport_document), class: 'fw-semibold text-decoration-none'
  end

  private

  def manifest_show_menu(manifest)
    Menu.new(name: :show, record: manifest, url: manifest_path(manifest), icon: :eye)
  end
end
