module Atua
  class SaveTransportDocumentsCommand < SaveReportCommand
    MODEL = TransportDocument
    MAPPER = MapTransportDocumentsCommand
    PREVIOUS_ATTRIBUTES = %i[charged_at nfse_pending_at].freeze
    MANIFEST_COLUMN = 'nr_mdfe'.freeze

    def call
      super.tap do
        DiscardInternalTakerDocumentsCommand.call(tenant)
        MacroRegions::AssignCommand.call(tenant)
      end
    end

    private

    def save_children(records)
      rows = records.flat_map do |record|
        record[:manifest_numbers].uniq.map { |number| manifest_link(record, number) }
      end

      replace(TransportDocumentManifest, manifest_links(records.pluck(:code)), rows)
    end

    def manifest_link(record, number)
      import_attributes(
        transport_document_code: record[:code],
        manifest_number: number.to_s,
        branch_name: record[:branch_name],
        raw_data: record[:raw_data].slice(MANIFEST_COLUMN),
      )
    end

    def mark_children_removed(codes)
      manifest_links(codes).active.update_all(removed_from_atua_at: imported_at, updated_at: imported_at)
    end

    def manifest_links(codes)
      TransportDocumentManifest.where(tenant_id:, transport_document_code: codes)
    end
  end
end
