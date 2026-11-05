module Atua
  class ReimportManifestsWithMissingDocumentsCommand
    REPORT_TYPES = %w[transport_documents manifests].freeze

    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      months.flat_map do |month|
        REPORT_TYPES.map { |report_type| ImportReportJob.perform_later(tenant.id, report_type, month, month.end_of_month) }
      end
    end

    private

    attr_reader :tenant

    def months
      issued_months = manifests.where.not(issued_on: nil).distinct.pluck(:issued_on).map(&:beginning_of_month)

      (issued_months + issued_months.map(&:prev_month)).uniq.sort.select { |month| month >= PurgeMovementsBeforeCommand::CUTOFF }
    end

    def manifests
      tenant.atua_manifests.active.not_canceled.where.not(plate: [nil, '']).where(code: documents.select(:manifest_code))
    end

    def documents
      documents = ManifestDocument.arel_table
      transport_documents = TransportDocument.arel_table
      transport_document = TransportDocument.where(transport_documents[:tenant_id].eq(documents[:tenant_id]))
        .where(transport_documents[:number].eq(documents[:transport_document_number]))
        .where(transport_documents[:series].eq(documents[:transport_document_series]))
        .where(transport_documents[:branch_name].eq(documents[:branch_name]))

      tenant.atua_manifest_documents.active.where(transport_document.arel.exists.not)
    end
  end
end
