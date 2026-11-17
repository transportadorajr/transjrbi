class MaintenanceServiceForm < MaintenanceCatalogItemForm
  PERMITTED_ATTRIBUTES = %i[code description price active].freeze

  attribute :price, :string

  class << self
    def attributes_of(service)
      { price: format_cents(service.price_cents) }
    end
  end

  private

  def items
    tenant.maintenance_services
  end

  def price_attribute
    :price
  end

  def item_attributes
    { price_cents: self.class.parse_cents(price) || 0 }
  end
end
