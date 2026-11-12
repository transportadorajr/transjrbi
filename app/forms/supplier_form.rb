class SupplierForm < BaseForm
  DOCUMENT_LENGTHS = [11, 14].freeze

  attribute :name, :string
  attribute :document, :string
  attribute :active, :boolean, default: true

  before_validation :normalize_fields

  validates :name, presence: true
  validate :name_must_be_available
  validate :document_must_have_valid_length

  attr_accessor :tenant
  attr_writer :supplier

  delegate :id, :persisted?, to: :supplier

  class << self
    def for_supplier(supplier)
      form = new(name: supplier.name, document: supplier.document, active: supplier.active, tenant: supplier.tenant)
      form.supplier = supplier
      form
    end
  end

  def supplier
    @supplier ||= tenant.suppliers.new
  end

  def submit
    supplier.update!(name:, document:, active:)
  end

  private

  def normalize_fields
    self.name = name.to_s.squish.upcase
    self.document = document.to_s.strip.presence
  end

  def name_must_be_available
    return if name.blank?

    others = persisted? ? tenant.suppliers.where.not(id: supplier.id) : tenant.suppliers
    errors.add(:name, :taken) if others.exists?(name:)
  end

  def document_must_have_valid_length
    return if document.blank? || DOCUMENT_LENGTHS.include?(document.delete('^0-9').length)

    errors.add(:document, :invalid)
  end
end
