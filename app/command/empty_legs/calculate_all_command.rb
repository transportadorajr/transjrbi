module EmptyLegs
  class CalculateAllCommand
    class << self
      def call(tenant, start_date: nil, client: nil)
        new(tenant, start_date:, client:).call
      end
    end

    def initialize(tenant, start_date: nil, client: nil)
      @tenant = tenant
      @start_date = start_date
      @client = client
    end

    def call
      tenant.empty_legs.where.not(next_manifest_code: nil).where.not(next_manifest_code: tenant.atua_manifests.trips.select(:code)).delete_all
      tenant.empty_legs.where.not(next_transport_document_code: nil)
        .where.not(next_transport_document_code: tenant.atua_transport_documents.ce_trips.select(:code)).delete_all

      (trips.find_each.to_a + ce_trips.find_each.to_a).filter_map { |trip| CalculateCommand.call(trip, client:) }
    end

    private

    attr_reader :tenant, :start_date, :client

    def trips
      start_date ? tenant.atua_manifests.trips.by_period_start(start_date) : tenant.atua_manifests.trips
    end

    def ce_trips
      start_date ? tenant.atua_transport_documents.ce_trips.by_period(start_date, nil) : tenant.atua_transport_documents.ce_trips
    end
  end
end
