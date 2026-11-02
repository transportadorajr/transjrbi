module Atua
  class ApplyInternationalVehicleCommand
    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      tenant.atua_transport_documents.billing_only.where(outside_international_vehicle)
        .update_all(**international_vehicle, updated_at: Time.current)
    end

    private

    attr_reader :tenant

    def outside_international_vehicle
      international_vehicle.map { |column, value| table[column].is_distinct_from(value) }.reduce(:or)
    end

    def international_vehicle
      @international_vehicle ||= TransportDocument.international_vehicle(tenant)
    end

    def table
      TransportDocument.arel_table
    end
  end
end
