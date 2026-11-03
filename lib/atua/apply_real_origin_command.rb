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
      Cities::RegisterOriginsCommand.call(tenant)
      MacroRegions::AssignCommand.call(tenant)

      updated
    end

    private

    attr_reader :tenant

    def billing_only_documents
      tenant.atua_transport_documents.billing_only
        .where(TransportDocument.arel_table[:origin_city].is_distinct_from(MapTransportDocumentsCommand::REAL_ORIGIN[:origin_city]))
    end
  end
end
