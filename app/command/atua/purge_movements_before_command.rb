module Atua
  class PurgeMovementsBeforeCommand
    CUTOFF = Date.new(2026, 4, 1)

    class << self
      def call(tenant, cutoff = CUTOFF)
        new(tenant, cutoff).call
      end
    end

    def initialize(tenant, cutoff)
      @tenant = tenant
      @cutoff = cutoff.to_date
    end

    def call
      purged = TransportDocument.transaction { purge_manifests + purge_transport_documents + purge_expenses }
      return purged if purged.zero?

      LinkExpensesCommand.call(tenant)
      EmptyLegs::ScheduleCalculationCommand.call(tenant.id)
      purged
    end

    private

    attr_reader :tenant, :cutoff

    def purge_manifests
      codes = tenant.atua_manifests.where(issued_on: ...cutoff).select(:code)

      tenant.empty_legs.where(previous_manifest_code: codes).or(tenant.empty_legs.where(next_manifest_code: codes)).delete_all
      tenant.atua_manifest_documents.where(manifest_code: codes).delete_all
      tenant.atua_manifests.where(issued_on: ...cutoff).delete_all
    end

    def purge_transport_documents
      documents = tenant.atua_transport_documents.where(issued_at: ...cutoff.in_time_zone)

      tenant.freight_expenses.where(transport_document_id: documents.select(:id)).delete_all
      tenant.atua_transport_document_manifests.where(transport_document_code: documents.select(:code)).delete_all
      EmptyLegTransportDocument.where(tenant_id: tenant.id, transport_document_code: documents.select(:code)).delete_all
      documents.delete_all
    end

    def purge_expenses
      tenant.atua_expenses.where(posted_on: ...cutoff).delete_all
    end
  end
end
