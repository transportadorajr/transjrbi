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
    t('transport_documents.route', origin: fiscal_city(document.origin_city, document.origin_state),
                                   destination: fiscal_city(document.destination_city, document.destination_state))
  end

  private

  def manifest_show_menu(manifest)
    Menu.new(name: :show, record: manifest, url: manifest_path(manifest), icon: :eye)
  end
end
