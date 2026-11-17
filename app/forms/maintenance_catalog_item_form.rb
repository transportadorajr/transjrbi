class MaintenanceCatalogItemForm < BaseForm
  attribute :code, :string
  attribute :description, :string
  attribute :active, :boolean, default: true

  before_validation :normalize_catalog_fields

  validates :description, presence: true
  validate :code_must_be_available
  validate :description_must_be_available
  validate :price_must_not_be_negative

  attr_accessor :tenant
  attr_writer :item

  delegate :id, :persisted?, to: :item

  class << self
    def for_item(item)
      form = new(tenant: item.tenant, code: item.code, description: item.description, active: item.active, **attributes_of(item))
      form.item = item
      form
    end
  end

  def item
    @item ||= items.new
  end

  def submit
    item.update!(code:, description:, active:, **item_attributes)
  end

  private

  def normalize_catalog_fields
    self.code = code.to_s.squish.upcase.presence
    self.description = description.to_s.squish.upcase
  end

  def others
    persisted? ? items.where.not(id: item.id) : items
  end

  def code_must_be_available
    errors.add(:code, :taken) if code.present? && others.exists?(code:)
  end

  def description_must_be_available
    errors.add(:description, :taken) if description.present? && others.exists?(description:)
  end

  def price_must_not_be_negative
    value = public_send(price_attribute)
    return if value.blank? || self.class.parse_cents(value)&.>=(0)

    errors.add(price_attribute, :invalid)
  end
end
