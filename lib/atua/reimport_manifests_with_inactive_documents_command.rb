module Atua
  class ReimportManifestsWithInactiveDocumentsCommand
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
      issued_dates = manifests.pluck(:issued_on) + inactive_transport_documents.pluck(:issued_at).compact.map(&:to_date)

      issued_dates.compact.map(&:beginning_of_month).uniq.sort.select { |month| month >= PurgeMovementsBeforeCommand::CUTOFF }
    end

    def manifests
      tenant.atua_manifests.trips.where(code: documents.select(:manifest_code))
    end

    def inactive_transport_documents
      TransportDocument.where(id: documents.select(TransportDocument.arel_table[:id]))
    end

    def documents
      tenant.atua_manifest_documents.active.joins(:transport_document)
        .merge(TransportDocument.removed_from_atua.or(TransportDocument.canceled))
        .merge(TransportDocument.where.not(plate: DiscardExcludedPlatesCommand::PLATES).or(TransportDocument.where(plate: nil)))
        .where.not(TransportDocument.arel_table[:id].in(TransportDocument.with_internal_taker.select(:id).arel))
    end
  end
end
