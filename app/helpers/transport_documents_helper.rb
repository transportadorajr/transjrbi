module TransportDocumentsHelper
  TOLL_BADGE_KINDS = { in_freight: :primary, outside_freight: :info, none: :secondary }.freeze

  def transport_documents_menu(transport_document)
    menus = []

    menus << transport_document_show_menu(transport_document) if can?(:read, :transport_documents)

    menus
  end

  def transport_document_route(transport_document)
    t('transport_documents.route',
      origin: tax_city(transport_document.origin_city, transport_document.origin_state),
      destination: tax_city(transport_document.destination_city, transport_document.destination_state))
  end

  def transport_document_kind(transport_document)
    return t('tax.blank') if transport_document.document_kind.blank?

    t(transport_document.document_kind, scope: 'transport_documents.document_kinds')
  end

  def transport_document_party(name, document)
    return t('tax.blank') if name.blank?

    safe_join([content_tag(:span, name, class: 'd-block'), (content_tag(:span, document, class: 'text-muted text-small d-block') if document.present?)], ' ')
  end

  def transport_document_toll(transport_document)
    content_tag :span, class: 'd-inline-flex flex-wrap align-items-center gap-2' do
      safe_join([tax_money(transport_document.toll), transport_document_toll_badge(transport_document)], ' ')
    end
  end

  def transport_document_toll_badge(transport_document)
    placement = transport_document.toll_placement

    status_badge(t(placement, scope: 'transport_documents.toll_placements'), kind: TOLL_BADGE_KINDS.fetch(placement))
  end

  def transport_document_empty_legs(empty_legs)
    return content_tag(:p, t('transport_documents.show.no_empty_leg'), class: 'text-body-secondary mb-0') if empty_legs.none?

    content_tag(:div, render(partial: 'transport_documents/empty_leg', collection: empty_legs), class: 'd-flex flex-column gap-4')
  end

  def transport_document_expenses(expenses, total)
    return if expenses.nil?

    render 'transport_documents/expenses/card', expenses:, total:
  end

  def transport_document_expenses_table(expenses, total)
    return content_tag(:p, t('transport_documents.show.no_expenses'), class: 'text-body-secondary mb-0') if expenses.none?

    render 'transport_documents/expenses/table', expenses:, total:
  end

  def transport_document_freight_expenses(freight_expenses, total)
    return if freight_expenses.blank?

    render 'transport_documents/freight_expenses/card', freight_expenses:, total:
  end

  def transport_document_manifests_table(manifests)
    return render('shared/no_content') if manifests.none?

    render 'transport_documents/manifests/table', manifests:
  end

  def transport_document_manifest_number(manifest)
    return manifest.number unless can?(:read, :manifests)

    link_to manifest.number, manifest_path(manifest), class: 'fw-semibold text-decoration-none'
  end

  private

  def transport_document_show_menu(transport_document)
    Menu.new(name: :show, record: transport_document, url: transport_document_path(transport_document), icon: :eye)
  end
end
