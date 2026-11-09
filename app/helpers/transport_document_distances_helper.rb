module TransportDocumentDistancesHelper
  def transport_document_distance_hint(transport_document)
    t('transport_document_distances.form.distance_km_hint', distance: tax_decimal(transport_document.atua_distance_km))
  end
end
