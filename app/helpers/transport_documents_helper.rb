module TransportDocumentsHelper
  def transport_documents_menu(transport_document)
    menus = []

    menus << transport_document_show_menu(transport_document) if can?(:read, :transport_documents)

    menus
  end

  def transport_document_route(transport_document)
    t('transport_documents.route',
      origin: fiscal_city(transport_document.origin_city, transport_document.origin_state),
      destination: fiscal_city(transport_document.destination_city, transport_document.destination_state))
  end

  def transport_document_kind(transport_document)
    return t('fiscal.blank') if transport_document.document_kind.blank?

    t(transport_document.document_kind, scope: 'transport_documents.document_kinds')
  end

  def transport_document_party(name, document)
    return t('fiscal.blank') if name.blank?

    safe_join([content_tag(:span, name, class: 'd-block'), (content_tag(:span, document, class: 'text-muted text-small d-block') if document.present?)], ' ')
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
