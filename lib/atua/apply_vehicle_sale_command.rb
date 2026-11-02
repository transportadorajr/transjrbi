module Atua
  class ApplyVehicleSaleCommand
    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      ids = documents.pluck(:id)
      return 0 if ids.empty?

      TransportDocument.transaction do
        FreightExpense.where(transport_document_id: ids).delete_all
        tenant.atua_transport_documents.where(id: ids).update_all(vehicle_sale: true, updated_at: Time.current)
      end

      ids.size
    end

    private

    attr_reader :tenant

    def documents
      tenant.atua_transport_documents.freights.where(TransportDocument.vehicle_sale_condition)
    end
  end
end
