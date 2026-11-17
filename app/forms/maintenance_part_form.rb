class MaintenancePartForm < MaintenanceCatalogItemForm
  PERMITTED_ATTRIBUTES = %i[code description unit brand unit_price active].freeze

  attribute :unit, :string
  attribute :brand, :string
  attribute :unit_price, :string

  before_validation :normalize_fields

  class << self
    def attributes_of(part)
      { unit: part.unit, brand: part.brand, unit_price: format_cents(part.unit_price_cents) }
    end
  end

  private

  def items
    tenant.maintenance_parts
  end

  def price_attribute
    :unit_price
  end

  def item_attributes
    { unit:, brand:, unit_price_cents: self.class.parse_cents(unit_price) || 0 }
  end

  def normalize_fields
    self.unit = unit.to_s.squish.upcase.presence
    self.brand = brand.to_s.squish.upcase.presence
  end
end
