class MacroRegionForm < BaseForm
  attribute :name, :string
  attribute :state, :string
  attribute :city_ids, default: -> { [] }
  attribute :remaining_state, :boolean, default: false

  before_validation :normalize_fields

  validates :name, :state, presence: true
  validates :state, format: { with: /\A[A-Z]{2}\z/ }, allow_blank: true
  validate :name_must_be_unique
  validate :listed_region_must_have_cities
  validate :remaining_state_must_be_unique
  validate :cities_must_belong_to_the_state
  validate :cities_must_not_be_in_another_region

  attr_accessor :tenant
  attr_writer :macro_region

  delegate :id, :persisted?, to: :macro_region

  class << self
    def for_macro_region(macro_region)
      form = new(name: macro_region.name, state: macro_region.state, city_ids: macro_region.city_ids,
                 remaining_state: macro_region.remaining_state, tenant: macro_region.tenant)
      form.macro_region = macro_region
      form
    end
  end

  def macro_region
    @macro_region ||= tenant.macro_regions.new
  end

  def selected_cities
    return City.none if remaining_state

    tenant.cities.where(id: city_ids)
  end

  def available_cities
    tenant.cities.where(macro_region_id: [nil, macro_region.id, *remaining_region_ids].uniq).order(:state, City.sort_text(City.arel_table[:name]))
  end

  def submit
    transaction do
      macro_region.update!(name:, state:, remaining_state:)
      macro_region.cities = selected_cities.to_a unless remaining_state
    end

    MacroRegions::AssignRemainingStateCommand.call(tenant)
    MacroRegions::AssignCommand.call(tenant)
  end

  private

  def normalize_fields
    self.name = name.to_s.squish
    self.state = state.to_s.squish.upcase
    self.city_ids = Array(city_ids).compact_blank.map(&:to_i).uniq
  end

  def name_must_be_unique
    return if name.blank? || other_regions.where(name:).none?

    errors.add(:name, :taken)
  end

  def listed_region_must_have_cities
    return if remaining_state || selected_cities.any?

    errors.add(:city_ids, :blank)
  end

  def remaining_state_must_be_unique
    return unless remaining_state && other_regions.exists?(state:, remaining_state: true)

    errors.add(:remaining_state, :taken)
  end

  def cities_must_belong_to_the_state
    other_state = selected_cities.where.not(state:).pluck(:name)

    errors.add(:city_ids, :other_state, cities: other_state.to_sentence, state:) if state.present? && other_state.any?
  end

  def cities_must_not_be_in_another_region
    taken = selected_cities.where.not(macro_region_id: [nil, macro_region.id, *remaining_region_ids]).pluck(:name)

    errors.add(:city_ids, :taken, cities: taken.to_sentence) if taken.any?
  end

  def remaining_region_ids
    tenant.macro_regions.where(remaining_state: true).ids
  end

  def other_regions
    persisted? ? tenant.macro_regions.where.not(id: macro_region.id) : tenant.macro_regions
  end
end
