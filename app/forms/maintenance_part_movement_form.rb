class MaintenancePartMovementForm < BaseForm
  TYPES = %i[entry adjustment].freeze
  PERMITTED_ATTRIBUTES = %i[movement_type maintenance_part_id moved_on quantity unit_cost supplier_id invoice_number notes].freeze

  attribute :movement_type, :string, default: 'entry'
  attribute :maintenance_part_id, :integer
  attribute :moved_on, :date
  attribute :quantity, :string
  attribute :unit_cost, :string
  attribute :supplier_id, :integer
  attribute :invoice_number, :string
  attribute :notes, :string

  enum :movement_type, TYPES

  before_validation :normalize_fields

  validates :movement_type, :maintenance_part_id, :moved_on, :quantity, presence: true
  validates :movement_type, inclusion: { in: TYPES.map(&:to_s) }, allow_blank: true
  validates :notes, presence: true, if: :movement_type_adjustment?
  validate :maintenance_part_must_be_available
  validate :supplier_must_be_available
  validate :moved_on_must_not_be_in_the_future
  validate :quantity_must_be_valid
  validate :unit_cost_must_not_be_negative
  validate :adjustment_must_change_balance

  attr_accessor :tenant, :created_by

  class << self
    def enum_i18n_key
      MaintenancePartMovement.model_name.i18n_key
    end
  end

  def maintenance_parts
    tenant.maintenance_parts.active.order(:description)
  end

  def suppliers
    tenant.suppliers.active.order(:name)
  end

  def maintenance_part
    @maintenance_part ||= maintenance_parts.find_by(id: maintenance_part_id) if maintenance_part_id.present?
  end

  def quantity_value
    self.class.parse_decimal(quantity)
  end

  def submit
    MaintenanceParts::RegisterMovementCommand.call(maintenance_part, movement_type:, moved_on:, quantity: movement_quantity,
                                                                     created_by:, **type_attributes)
  end

  private

  def movement_quantity
    movement_type_adjustment? ? quantity_value - maintenance_part.quantity : quantity_value
  end

  def type_attributes
    if movement_type_entry?
      { unit_cost_cents: self.class.parse_cents(unit_cost), supplier_id:, invoice_number:, notes: }
    else
      { notes: }
    end
  end

  def normalize_fields
    self.invoice_number = invoice_number.to_s.squish.presence
    self.notes = notes.to_s.strip.presence
  end

  def maintenance_part_must_be_available
    errors.add(:maintenance_part_id, :inclusion) if maintenance_part_id.present? && maintenance_part.nil?
  end

  def supplier_must_be_available
    return if supplier_id.blank? || !movement_type_entry? || suppliers.exists?(id: supplier_id)

    errors.add(:supplier_id, :inclusion)
  end

  def moved_on_must_not_be_in_the_future
    errors.add(:moved_on, :future) if moved_on.present? && moved_on > Time.zone.today
  end

  def quantity_must_be_valid
    return if quantity.blank?

    value = quantity_value
    valid = movement_type_adjustment? ? value&.>=(0) : value&.positive?
    errors.add(:quantity, movement_type_adjustment? ? :greater_than_or_equal_to : :greater_than, count: 0) unless valid
  end

  def unit_cost_must_not_be_negative
    return if unit_cost.blank? || self.class.parse_cents(unit_cost)&.>=(0)

    errors.add(:unit_cost, :invalid)
  end

  def adjustment_must_change_balance
    return unless movement_type_adjustment? && maintenance_part && quantity_value
    return unless quantity_value == maintenance_part.quantity

    errors.add(:quantity, :unchanged)
  end
end
