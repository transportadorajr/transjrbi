class MaintenanceOrderServiceForm < MaintenanceOrderItemForm
  PERMITTED_ATTRIBUTES = %i[supplier_id description quote_number quoted approved approved_by_name invoice_number].freeze

  attribute :supplier_id, :integer
  attribute :description, :string
  attribute :quote_number, :string
  attribute :quoted, :string
  attribute :approved, :string
  attribute :approved_by_name, :string
  attribute :invoice_number, :string

  before_validation :normalize_fields

  validates :supplier_id, :description, presence: true
  validate :supplier_must_be_available
  validate :values_must_not_be_negative

  class << self
    def attributes_of(service)
      { supplier_id: service.supplier_id, description: service.description, quote_number: service.quote_number,
        quoted: format_cents(service.quoted_cents), approved: format_cents(service.approved_cents),
        approved_by_name: service.approved_by_name, invoice_number: service.invoice_number }
    end
  end

  def suppliers
    tenant.suppliers.where(active: true).or(tenant.suppliers.where(id: item.supplier_id)).order(:name)
  end

  private

  def items
    maintenance_order.services
  end

  def item_attributes
    { supplier_id:, description:, quote_number:, quoted_cents: self.class.parse_cents(quoted),
      approved_cents: self.class.parse_cents(approved), approved_by_name:, invoice_number: }
  end

  def normalize_fields
    self.description = description.to_s.squish
    self.quote_number = quote_number.to_s.squish.presence
    self.approved_by_name = approved_by_name.to_s.squish.upcase.presence
    self.invoice_number = invoice_number.to_s.squish.presence
  end

  def supplier_must_be_available
    return if supplier_id.blank? || suppliers.exists?(id: supplier_id)

    errors.add(:supplier_id, :inclusion)
  end

  def values_must_not_be_negative
    { quoted:, approved: }.each do |attribute, value|
      next if value.blank? || self.class.parse_cents(value)&.>=(0)

      errors.add(attribute, :invalid)
    end
  end
end
