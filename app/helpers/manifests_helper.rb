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

  def empty_leg_previous_manifest(empty_leg)
    manifest = empty_leg.previous_manifest
    return empty_leg.previous_manifest_code.to_s unless manifest&.active?

    link_to manifest.number, manifest_path(manifest), class: 'fw-semibold text-decoration-none'
  end

  def empty_leg_location(location)
    return t('tax.blank') unless location

    [location.street, tax_city(location.city, location.state)].compact_blank.join(' - ')
  end

  def empty_leg_distance(empty_leg)
    return empty_leg.status_type_name unless empty_leg.calculated?

    t('manifests.empty_leg.distance', distance: number_with_precision(empty_leg.distance_km, precision: 2))
  end

  private

  def manifest_show_menu(manifest)
    Menu.new(name: :show, record: manifest, url: manifest_path(manifest), icon: :eye)
  end
end
