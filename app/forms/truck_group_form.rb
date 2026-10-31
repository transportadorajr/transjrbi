class TruckGroupForm < BaseForm
  PLATE_FORMAT = /\A[A-Z]{3}\d[A-Z0-9]\d{2}\z/
  PLATE_SEPARATORS = /[\s,;]+/

  attribute :name, :string
  attribute :axles, default: -> { [] }
  attribute :fuel_percentage, :string
  attribute :fuel_valid_month, :string, default: -> { Date.current.strftime('%Y-%m') }
  attribute :plates, :string
  attribute :remaining_axles, :boolean, default: false
  attribute :active, :boolean, default: true

  before_validation :normalize_fields

  validates :name, presence: true
  validate :name_must_be_unique
  validate :axles_must_be_valid
  validate :axles_must_not_be_in_another_group
  validate :plates_must_be_valid
  validate :plates_must_not_be_in_another_group
  validate :remaining_axles_must_be_unique
  validates :fuel_percentage, presence: true
  validates :fuel_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_blank: true
  validate :fuel_valid_month_must_be_a_past_or_current_month

  attr_accessor :tenant
  attr_writer :truck_group

  delegate :id, :persisted?, to: :truck_group

  class << self
    def for_truck_group(truck_group)
      form = new(name: truck_group.name, axles: truck_group.axles, fuel_percentage: format_percentage(truck_group.fuel_percentage),
                 plates: truck_group.plates.join("\n"), remaining_axles: truck_group.remaining_axles, active: truck_group.activated?, tenant: truck_group.tenant)
      form.truck_group = truck_group
      form
    end

    def format_percentage(percentage)
      ActiveSupport::NumberHelper.number_to_rounded(percentage, precision: 4, strip_insignificant_zeros: true,
                                                                separator: '.', delimiter: '')
    end
  end

  def truck_group
    @truck_group ||= tenant.truck_groups.new
  end

  def axle_list
    return [] if remaining_axles

    Array(axles).compact_blank.map(&:to_i).uniq.sort
  end

  def plate_list
    return [] if remaining_axles

    plates.to_s.split(PLATE_SEPARATORS).compact_blank.map { |plate| Atua::TransportDocument.normalize_plate(plate) }.uniq.sort
  end

  def fuel_valid_month_value
    TonnageRate.parse_month(fuel_valid_month) if fuel_valid_month.to_s.match?(/\A\d{4}-\d{2}\z/)
  end

  def submit
    transaction do
      truck_group.fuel_percentage = BigDecimal(fuel_percentage) unless persisted?
      truck_group.update!(name:, axles: axle_list, plates: plate_list, remaining_axles:, activated: active)
      truck_group.change_fuel_percentage(BigDecimal(fuel_percentage), fuel_valid_month_value)
    end

    FreightExpenses::CalculateFuelCommand.call(tenant)
  end

  private

  def normalize_fields
    self.name = name.to_s.squish
  end

  def name_must_be_unique
    return if name.blank? || other_groups.where(name:).none?

    errors.add(:name, :taken)
  end

  def fuel_valid_month_must_be_a_past_or_current_month
    if fuel_valid_month_value.nil?
      errors.add(:fuel_valid_month, :invalid)
    elsif fuel_valid_month_value > Date.current
      errors.add(:fuel_valid_month, :future)
    end
  end

  def axles_must_be_valid
    return if remaining_axles

    if axle_list.empty?
      errors.add(:axles, :blank) if plate_list.empty?
    elsif (axle_list - TruckGroup::AXLE_OPTIONS).any?
      errors.add(:axles, :inclusion)
    end
  end

  def axles_must_not_be_in_another_group
    return unless active

    taken = axle_list & other_groups.activated.pluck(:axles).flatten
    errors.add(:axles, :taken, axles: taken.to_sentence) if taken.any?
  end

  def plates_must_be_valid
    invalid = plate_list.grep_v(PLATE_FORMAT)

    errors.add(:plates, :invalid, plates: invalid.to_sentence) if invalid.any?
  end

  def plates_must_not_be_in_another_group
    return unless active

    taken = plate_list & other_groups.activated.pluck(:plates).flatten
    errors.add(:plates, :taken, plates: taken.to_sentence) if taken.any?
  end

  def remaining_axles_must_be_unique
    return unless active && remaining_axles && other_groups.activated.exists?(remaining_axles: true)

    errors.add(:remaining_axles, :taken)
  end

  def other_groups
    persisted? ? tenant.truck_groups.where.not(id: truck_group.id) : tenant.truck_groups
  end
end
