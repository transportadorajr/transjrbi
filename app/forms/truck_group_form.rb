class TruckGroupForm < BaseForm
  attribute :name, :string
  attribute :axles, default: -> { [] }
  attribute :fuel_percentage, :string
  attribute :active, :boolean, default: true

  before_validation :normalize_fields

  validates :name, presence: true
  validate :name_must_be_unique
  validate :axles_must_be_valid
  validate :axles_must_not_be_in_another_group
  validate :fuel_percentage_must_be_in_range

  attr_accessor :tenant
  attr_writer :truck_group

  delegate :id, :persisted?, to: :truck_group

  class << self
    def for_truck_group(truck_group)
      form = new(name: truck_group.name, axles: truck_group.axles, fuel_percentage: format_percentage(truck_group.fuel_percentage),
                 active: truck_group.activated?, tenant: truck_group.tenant)
      form.truck_group = truck_group
      form
    end

    delegate :format_percentage, to: :InsuranceRateForm
  end

  def truck_group
    @truck_group ||= tenant.truck_groups.new
  end

  def axle_list
    Array(axles).compact_blank.map(&:to_i).uniq.sort
  end

  def fuel_percentage_value
    InsuranceRateForm.parse_percentage(fuel_percentage)
  end

  def submit
    truck_group.update!(name:, axles: axle_list, fuel_percentage: fuel_percentage_value, activated: active)

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

  def fuel_percentage_must_be_in_range
    value = fuel_percentage_value
    return if value && !value.negative? && value <= 100

    errors.add(:fuel_percentage, :out_of_range)
  end

  def other_groups
    persisted? ? tenant.truck_groups.where.not(id: truck_group.id) : tenant.truck_groups
  end
end
