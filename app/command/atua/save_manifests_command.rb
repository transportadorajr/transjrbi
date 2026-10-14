module Atua
  class SaveManifestsCommand < SaveReportCommand
    MODEL = Manifest
    MAPPER = MapManifestsCommand
    CHILDREN = %i[documents].freeze
    DOCUMENT_KEY = %i[transport_document_number transport_document_series].freeze

    private

    def save_children(records)
      rows = records.flat_map do |record|
        record[:documents].uniq { |document| document.values_at(*DOCUMENT_KEY) }.map { |document| import_attributes(document) }
      end

      replace(ManifestDocument, documents(records.pluck(:code)), rows)
    end

    def mark_children_removed(codes)
      documents(codes).active.update_all(removed_from_atua_at: imported_at, updated_at: imported_at)
    end

    def documents(codes)
      ManifestDocument.where(tenant_id:, manifest_code: codes)
    end
  end
end
