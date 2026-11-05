module Atua
  class DiscardIcmsComplementsCommand
    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      ids, codes = documents.pluck(:id, :code).transpose
      return 0 if ids.blank?

      discard(ids, codes)
      LinkExpensesCommand.call(tenant)

      ids.size
    end

    private

    attr_reader :tenant

    def documents
      tenant.atua_transport_documents.active.icms_complements
    end

    def discard(ids, codes)
      now = Time.current

      TransportDocument.transaction do
        FreightExpense.where(transport_document_id: ids).delete_all
        tenant.atua_transport_document_manifests.active.where(transport_document_code: codes)
          .update_all(removed_from_atua_at: now, updated_at: now)
        tenant.atua_transport_documents.where(id: ids).update_all(removed_from_atua_at: now, updated_at: now)
      end
    end
  end
end
