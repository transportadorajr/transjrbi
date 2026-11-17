module MaintenanceParts
  class RegisterMovementCommand
    class << self
      def call(maintenance_part, **attributes)
        new(maintenance_part, attributes).call
      end
    end

    def initialize(maintenance_part, attributes)
      @maintenance_part = maintenance_part
      @attributes = attributes
    end

    def call
      maintenance_part.with_lock do
        balance = maintenance_part.quantity + attributes.fetch(:quantity)
        movement = maintenance_part.movements.create!(tenant: maintenance_part.tenant, balance:, **attributes)
        maintenance_part.update!(quantity: balance, **cost_attributes)
        movement
      end
    end

    private

    attr_reader :maintenance_part, :attributes

    def cost_attributes
      cost = attributes[:unit_cost_cents]
      attributes[:movement_type].to_s == 'entry' && cost.to_i.positive? ? { unit_price_cents: cost } : {}
    end
  end
end
