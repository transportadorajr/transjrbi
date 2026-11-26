module EmptyLegsHelper
  def empty_leg_manifest_link(manifest, code)
    return code.to_s unless manifest
    return manifest.number unless manifest.active? && can?(:read, :manifests)

    link_to manifest.number, manifest_path(manifest), class: 'fw-semibold text-decoration-none'
  end

  def empty_leg_previous_trip_link(empty_leg)
    return empty_leg_manifest_link(empty_leg.previous_manifest, empty_leg.previous_manifest_code) if empty_leg.previous_manifest_code

    empty_leg_ce_link(empty_leg.previous_transport_document, empty_leg.previous_transport_document_code)
  end

  def empty_leg_ce_link(transport_document, code)
    return code.to_s unless transport_document

    label = t('empty_legs.ce', number: transport_document.number)
    return label unless transport_document.active? && can?(:read, :transport_documents)

    link_to label, transport_document_path(transport_document), class: 'fw-semibold text-decoration-none'
  end

  def empty_leg_location(location)
    return t('tax.blank') unless location

    [location.street, tax_city(location.city, location.state)].compact_blank.join(' - ')
  end

  def empty_leg_total(total)
    t('empty_legs.distance', distance: number_with_precision(total, precision: 2))
  end

  def empty_leg_distance(empty_leg)
    return empty_leg.status_type_name unless empty_leg.calculated?

    t('empty_legs.distance', distance: number_with_precision(empty_leg.distance_km, precision: 2))
  end
end
