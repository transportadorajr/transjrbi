module DistanceAdjustments
  class RevertCommand
    class << self
      def call(tenant, transport_document_number)
        new(tenant, transport_document_number).call
      end
    end

    def initialize(tenant, transport_document_number)
      @tenant = tenant
      @transport_document_number = transport_document_number
    end

    def call
      documents.update_all(
        ['distance_km = original_distance_km, original_distance_km = NULL, distance_adjusted_at = NULL, updated_at = ?', Time.current],
      )
    end

    private

    attr_reader :tenant, :transport_document_number

    def documents
      tenant.atua_transport_documents.where(number: transport_document_number).where.not(distance_adjusted_at: nil)
    end
  end
end
