module MaintenanceOrders
  class DeductStockCommand
    class << self
      def call(maintenance_order, created_by: nil)
        new(maintenance_order, created_by).call
      end
    end

    def initialize(maintenance_order, created_by)
      @maintenance_order = maintenance_order
      @created_by = created_by
    end

    def call
      pending_parts.map do |part|
        MaintenanceParts::RegisterMovementCommand.call(
          part.maintenance_part, movement_type: :exit, quantity: -part.quantity, moved_on: maintenance_order.finished_at.to_date,
                                 maintenance_order:, maintenance_order_part: part, created_by:
        )
      end
    end

    private

    attr_reader :maintenance_order, :created_by

    def pending_parts
      maintenance_order.parts.stock.where.not(maintenance_part_id: nil).where.missing(:stock_movement).preload(:maintenance_part).order(:id)
    end
  end
end
