class TruckGroupForm < BaseForm
  attribute :name, :string
  attribute :axles, default: -> { [] }
  attribute :fuel_percentage, :string
  attribute :remaining_axles, :boolean, default: false
  attribute :active, :boolean, default: true

  before_validation :normalize_fields

  validates :name, presence: true
  validate :name_must_be_unique
  validate :axles_must_be_valid
  validate :axles_must_not_be_in_another_group
  validate :remaining_axles_must_be_unique
  validates :fuel_percentage, presence: true
  validates :fuel_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_blank: true

  attr_accessor :tenant
  attr_writer :truck_group

  delegate :id, :persisted?, to: :truck_group

  class << self
    def for_truck_group(truck_group)
      form = new(name: truck_group.name, axles: truck_group.axles, fuel_percentage: format_percentage(truck_group.fuel_percentage),
                 remaining_axles: truck_group.remaining_axles, active: truck_group.activated?, tenant: truck_group.tenant)
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

  def submit
    truck_group.update!(name:, axles: axle_list, remaining_axles:, fuel_percentage: BigDecimal(fuel_percentage), activated: active)

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

  def axles_must_be_valid
    return if remaining_axles

    if axle_list.empty?
      errors.add(:axles, :blank)
    elsif (axle_list - TruckGroup::AXLE_OPTIONS).any?
      errors.add(:axles, :inclusion)
    end
  end

  def axles_must_not_be_in_another_group
    return unless active

    taken = axle_list & other_groups.activated.pluck(:axles).flatten
    errors.add(:axles, :taken, axles: taken.to_sentence) if taken.any?
  end

  def remaining_axles_must_be_unique
    return unless active && remaining_axles && other_groups.activated.exists?(remaining_axles: true)

    errors.add(:remaining_axles, :taken)
  end

  def other_groups
    persisted? ? tenant.truck_groups.where.not(id: truck_group.id) : tenant.truck_groups
  end
end
