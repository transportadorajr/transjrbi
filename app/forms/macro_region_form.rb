class MacroRegionForm < BaseForm
  attribute :name, :string
  attribute :state, :string
  attribute :cities, :string
  attribute :remaining_state, :boolean, default: false

  before_validation :normalize_fields

  validates :name, :state, presence: true
  validates :state, format: { with: /\A[A-Z]{2}\z/ }, allow_blank: true
  validate :name_must_be_unique
  validate :listed_region_must_have_cities
  validate :remaining_state_must_be_unique
  validate :cities_must_not_be_in_another_region

  attr_accessor :tenant
  attr_writer :macro_region

  delegate :id, :persisted?, to: :macro_region

  class << self
    def for_macro_region(macro_region)
      form = new(name: macro_region.name, state: macro_region.state, cities: macro_region.cities.join("\n"),
                 remaining_state: macro_region.remaining_state, tenant: macro_region.tenant)
      form.macro_region = macro_region
      form
    end
  end

  def macro_region
    @macro_region ||= tenant.macro_regions.new
  end

  def city_list
    return [] if remaining_state

    cities.to_s.lines.map(&:squish).compact_blank.uniq { |city| CustomerGroup.compact(city) }
  end

  def submit
    macro_region.update!(name:, state:, cities: city_list, remaining_state:)

    MacroRegions::AssignCommand.call(tenant)
  end

  private

  def normalize_fields
    self.name = name.to_s.squish
    self.state = state.to_s.squish.upcase
  end

  def name_must_be_unique
    return if name.blank? || other_regions.where(name:).none?

    errors.add(:name, :taken)
  end

  def listed_region_must_have_cities
    return if remaining_state || city_list.any?

    errors.add(:cities, :blank)
  end

  def remaining_state_must_be_unique
    return unless remaining_state && other_regions.exists?(state:, remaining_state: true)

    errors.add(:remaining_state, :taken)
  end

  def cities_must_not_be_in_another_region
    regions = other_regions.where(state:).to_a
    taken = city_list.select { |city| regions.any? { |region| region.covers_city?(city) } }

    errors.add(:cities, :taken, cities: taken.to_sentence) if taken.any?
  end

  def other_regions
    persisted? ? tenant.macro_regions.where.not(id: macro_region.id) : tenant.macro_regions
  end
end
