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
        .where(document_kind: MapTransportDocumentsCommand::DOCUMENT_KINDS['CE'])
        .where(table[:origin_city].is_distinct_from(MapTransportDocumentsCommand::REAL_ORIGIN[:origin_city]))
        .where(table[:plate].eq(MapTransportDocumentsCommand::INTERNATIONAL_PLATE).or(billed_to_border))
    end

    def billed_to_border
      table[:destination_city].eq(MapTransportDocumentsCommand::BILLING_DESTINATION[:destination_city])
        .and(table[:destination_state].eq(MapTransportDocumentsCommand::BILLING_DESTINATION[:destination_state]))
        .and(table[:taker_name].matches("%#{MapTransportDocumentsCommand::BILLING_ORIGIN_TAKER}%"))
    end

    def table
      TransportDocument.arel_table
    end
  end
end
