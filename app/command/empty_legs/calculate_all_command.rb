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
      tenant.empty_legs.where.not(next_manifest_code: tenant.atua_manifests.trips.select(:code)).delete_all

      trips.find_each.filter_map { |manifest| CalculateCommand.call(manifest, client:) }
    end

    private

    attr_reader :tenant, :start_date, :client

    def trips
      start_date ? tenant.atua_manifests.trips.by_period_start(start_date) : tenant.atua_manifests.trips
    end
  end
end
