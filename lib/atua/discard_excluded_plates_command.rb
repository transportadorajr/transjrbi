module Atua
  class DiscardExcludedPlatesCommand
    PLATES = %w[BAM2A26].freeze

    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
      @now = Time.current
    end

    def call
      discarded = TransportDocument.transaction do
        discard_transport_documents + discard_manifests + discard(Expense) + discard(TollVoucher) + discard(Vehicle)
      end
      LinkExpensesCommand.call(tenant) if discarded.positive?

      discarded
    end

    private

    attr_reader :tenant, :now

    def discard_transport_documents
      ids, codes = excluded(TransportDocument).pluck(:id, :code).transpose
      return 0 if ids.blank?

      FreightExpense.where(transport_document_id: ids).delete_all
      remove(tenant.atua_transport_document_manifests.active.where(transport_document_code: codes))
      remove(TransportDocument.where(id: ids))
    end

    def discard_manifests
      codes = excluded(Manifest).pluck(:code)
      return 0 if codes.empty?

      remove(tenant.atua_manifest_documents.active.where(manifest_code: codes))
      remove(tenant.atua_manifests.where(code: codes))
    end

    def discard(model)
      remove(excluded(model))
    end

    def excluded(model)
      model.active.where(tenant_id: tenant.id, plate: PLATES)
    end

    def remove(relation)
      relation.update_all(removed_from_atua_at: now, updated_at: now)
    end
  end
end
