class MaintenanceOrderServiceForm < MaintenanceOrderItemForm
  PERMITTED_ATTRIBUTES = %i[maintenance_service_id supplier_id description quote_number quoted approved approved_by_name invoice_number].freeze

  attribute :maintenance_service_id, :integer
  attribute :supplier_id, :integer
  attribute :description, :string
  attribute :quote_number, :string
  attribute :quoted, :string
  attribute :approved, :string
  attribute :approved_by_name, :string
  attribute :invoice_number, :string

  before_validation :normalize_fields

  validates :supplier_id, :description, presence: true
  validate :maintenance_service_must_be_available
  validate :supplier_must_be_available
  validate :values_must_not_be_negative

  class << self
    def attributes_of(service)
      { maintenance_service_id: service.maintenance_service_id, supplier_id: service.supplier_id, description: service.description, quote_number: service.quote_number,
        quoted: format_cents(service.quoted_cents), approved: format_cents(service.approved_cents),
        approved_by_name: service.approved_by_name, invoice_number: service.invoice_number }
    end
  end

  def suppliers
    tenant.suppliers.where(active: true).or(tenant.suppliers.where(id: item.supplier_id)).order(:name)
  end

  def maintenance_services
    tenant.maintenance_services.active.or(tenant.maintenance_services.where(id: item.maintenance_service_id)).order(:description)
  end

  private

  def items
    maintenance_order.services
  end

  def item_attributes
    { maintenance_service_id:, supplier_id:, description:, quote_number:, quoted_cents: self.class.parse_cents(quoted),
      approved_cents: self.class.parse_cents(approved), approved_by_name:, invoice_number: }
  end

  def normalize_fields
    fill_from_catalog
    self.description = description.to_s.squish
    self.quote_number = quote_number.to_s.squish.presence
    self.approved_by_name = approved_by_name.to_s.squish.upcase.presence
    self.invoice_number = invoice_number.to_s.squish.presence
  end

  def catalog_service
    @catalog_service ||= maintenance_services.find_by(id: maintenance_service_id) if maintenance_service_id.present?
  end

  def fill_from_catalog
    return unless catalog_service

    self.description = catalog_service.description if description.blank?
    self.quoted = self.class.format_cents(catalog_service.price_cents) if quoted.blank? && catalog_service.price_cents.positive?
  end

  def maintenance_service_must_be_available
    errors.add(:maintenance_service_id, :inclusion) if maintenance_service_id.present? && catalog_service.nil?
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
