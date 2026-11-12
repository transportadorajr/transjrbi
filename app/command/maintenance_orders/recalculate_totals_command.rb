module MaintenanceOrders
  class RecalculateTotalsCommand
    class << self
      def call(maintenance_order)
        new(maintenance_order).call
      end
    end

    def initialize(maintenance_order)
      @maintenance_order = maintenance_order
    end

    def call
      maintenance_order.update!(parts_total_cents:, services_total_cents:, total_cents: parts_total_cents + services_total_cents)
      maintenance_order
    end

    private

    attr_reader :maintenance_order

    def parts_total_cents
      @parts_total_cents ||= maintenance_order.parts.sum(:total_cents)
    end

    def services_total_cents
      @services_total_cents ||= maintenance_order.services.sum(service_value)
    end

    def service_value
      service = MaintenanceOrderService.arel_table

      Arel::Nodes::NamedFunction.new('COALESCE', [service[:approved_cents], service[:quoted_cents], Arel::Nodes.build_quoted(0)])
    end
  end
end
