module Atua
  class ApplyRealOriginCommand
    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      updated = billing_only_documents.update_all(**MapTransportDocumentsCommand::REAL_ORIGIN, updated_at: Time.current)
      MacroRegions::AssignCommand.call(tenant)

      updated
    end

    private

    attr_reader :tenant

    def billing_only_documents
      tenant.atua_transport_documents
        .where(document_kind: MapTransportDocumentsCommand::DOCUMENT_KINDS['CE'], **MapTransportDocumentsCommand::BILLING_ORIGIN)
        .where(TransportDocument.arel_table[:taker_name].matches("%#{MapTransportDocumentsCommand::BILLING_ORIGIN_TAKER}%"))
    end
  end
end
