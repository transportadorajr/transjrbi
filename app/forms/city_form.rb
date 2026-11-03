class CityForm < BaseForm
  attribute :name, :string
  attribute :state, :string
  attribute :macro_region_id, :integer

  before_validation :normalize_fields

  validates :name, :state, presence: true
  validates :state, format: { with: /\A[A-Z]{2}\z/ }, allow_blank: true
  validate :name_must_be_unique
  validate :macro_region_must_list_cities_of_the_state

  attr_accessor :tenant
  attr_writer :city

  delegate :id, :persisted?, to: :city

  class << self
    def for_city(city)
      form = new(name: city.name, state: city.state, macro_region_id: city.macro_region_id, tenant: city.tenant)
      form.city = city
      form
    end
  end

  def city
    @city ||= tenant.cities.new
  end

  def macro_region
    tenant.macro_regions.find_by(id: macro_region_id) if macro_region_id.present?
  end

  def available_macro_regions
    tenant.macro_regions.where(remaining_state: false).order(:state, MacroRegion.sort_text(MacroRegion.arel_table[:name]))
  end

  def submit
    city.update!(name:, state:, macro_region:)

    MacroRegions::AssignRemainingStateCommand.call(tenant)
    MacroRegions::AssignCommand.call(tenant)
  end

  private

  def normalize_fields
    self.name = name.to_s.squish
    self.state = state.to_s.squish.upcase
  end

  def name_must_be_unique
    return if name.blank?

    compacted_name = CustomerGroup.compact(name)
    return if other_cities.where(state:).none? { |other_city| other_city.compacted_name == compacted_name }

    errors.add(:name, :taken, state:)
  end

  def macro_region_must_list_cities_of_the_state
    return if macro_region_id.blank?

    region = macro_region
    if region.nil? || region.remaining_state?
      errors.add(:macro_region_id, :invalid)
    elsif region.state != state
      errors.add(:macro_region_id, :other_state, state: region.state)
    end
  end

  def other_cities
    persisted? ? tenant.cities.where.not(id: city.id) : tenant.cities
  end
end
