class MaintenanceOrderPartForm < MaintenanceOrderItemForm
  PERMITTED_ATTRIBUTES = %i[maintenance_part_id code description quantity unit source_type document_number unit_price].freeze

  attribute :maintenance_part_id, :integer
  attribute :code, :string
  attribute :description, :string
  attribute :quantity, :string
  attribute :unit, :string
  attribute :source_type, :string, default: 'stock'
  attribute :document_number, :string
  attribute :unit_price, :string

  enum :source_type, MaintenanceOrderPart::SOURCES

  before_validation :normalize_fields

  validates :description, :quantity, :source_type, presence: true
  validates :source_type, inclusion: { in: MaintenanceOrderPart::SOURCES.map(&:to_s) }, allow_blank: true
  validate :maintenance_part_must_be_available
  validate :quantity_must_be_positive
  validate :unit_price_must_not_be_negative

  class << self
    def attributes_of(part)
      { maintenance_part_id: part.maintenance_part_id, code: part.code, description: part.description, quantity: format_decimal(part.quantity), unit: part.unit,
        source_type: part.source_type, document_number: part.document_number, unit_price: format_cents(part.unit_price_cents) }
    end
  end

  def maintenance_parts
    tenant.maintenance_parts.active.or(tenant.maintenance_parts.where(id: item.maintenance_part_id)).order(:description)
  end

  def quantity_value
    self.class.parse_decimal(quantity)
  end

  def unit_price_cents
    self.class.parse_cents(unit_price) || 0
  end

  def total_cents
    (quantity_value * unit_price_cents).round(0, BigDecimal::ROUND_HALF_UP).to_i
  end

  private

  def items
    maintenance_order.parts
  end

  def item_attributes
    { maintenance_part_id:, code:, description:, quantity: quantity_value, unit:, source_type:, document_number:, unit_price_cents:, total_cents: }
  end

  def normalize_fields
    fill_from_catalog
    self.code = code.to_s.squish.upcase.presence
    self.description = description.to_s.squish.upcase
    self.unit = unit.to_s.squish.upcase.presence
    self.document_number = document_number.to_s.squish.presence
  end

  def catalog_part
    @catalog_part ||= maintenance_parts.find_by(id: maintenance_part_id) if maintenance_part_id.present?
  end

  def fill_from_catalog
    return unless catalog_part

    self.code = catalog_part.code if code.blank?
    self.description = catalog_part.description if description.blank?
    self.unit = catalog_part.unit if unit.blank?
    self.unit_price = self.class.format_cents(catalog_part.unit_price_cents) if unit_price.blank?
  end

  def maintenance_part_must_be_available
    errors.add(:maintenance_part_id, :inclusion) if maintenance_part_id.present? && catalog_part.nil?
  end

  def quantity_must_be_positive
    return if quantity.blank?

    errors.add(:quantity, :greater_than, count: 0) unless quantity_value&.positive?
  end

  def unit_price_must_not_be_negative
    return if unit_price.blank? || self.class.parse_cents(unit_price)&.>=(0)

    errors.add(:unit_price, :invalid)
  end
end
