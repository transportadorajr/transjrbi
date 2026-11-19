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
      totals_by_type.fetch('MaintenanceOrderPart', 0)
    end

    def services_total_cents
      totals_by_type.fetch('MaintenanceOrderService', 0)
    end

    def totals_by_type
      @totals_by_type ||= maintenance_order.items.group(:itemizable_type).sum(:total_cents)
    end
  end
end
