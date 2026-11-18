class ExportPlantForm < BaseForm
  attribute :customer_group_id, :integer
  attribute :name, :string
  attribute :cities, :string
  attribute :active, :boolean, default: true

  before_validation :normalize_fields

  validates :customer_group_id, :name, presence: true
  validate :customer_group_must_belong_to_tenant
  validate :cities_must_be_present
  validate :name_must_be_unique
  validate :cities_must_not_be_in_another_plant

  attr_accessor :tenant
  attr_writer :export_plant

  delegate :id, :persisted?, to: :export_plant

  class << self
    def for_export_plant(export_plant)
      form = new(customer_group_id: export_plant.customer_group_id, name: export_plant.name, cities: export_plant.cities.join("\n"),
                 active: export_plant.activated?, tenant: export_plant.tenant)
      form.export_plant = export_plant
      form
    end
  end

  def export_plant
    @export_plant ||= tenant.export_plants.new
  end

  def customer_groups
    tenant.customer_groups.order(:name, :id)
  end

  def city_list
    cities.to_s.lines.map(&:squish).compact_blank.uniq { |city| CustomerGroup.compact(city) }
  end

  def submit
    export_plant.update!(customer_group_id:, name:, cities: city_list, activated: active)
  end

  private

  def normalize_fields
    self.name = name.to_s.squish
  end

  def customer_group_must_belong_to_tenant
    return if customer_group_id.blank? || tenant.customer_groups.exists?(customer_group_id)

    errors.add(:customer_group_id, :invalid)
  end

  def cities_must_be_present
    errors.add(:cities, :blank) if city_list.empty?
  end

  def name_must_be_unique
    return if name.blank? || other_plants.none? { |plant| plant.name.casecmp?(name) }

    errors.add(:name, :taken)
  end

  def cities_must_not_be_in_another_plant
    return unless active

    taken = city_list.select { |city| other_plants.any? { |plant| plant.activated? && plant.serves_city?(city) } }
    errors.add(:cities, :taken, cities: taken.to_sentence) if taken.any?
  end

  def other_plants
    @other_plants ||= begin
      plants = tenant.export_plants.where(customer_group_id:)
      (persisted? ? plants.where.not(id: export_plant.id) : plants).to_a
    end
  end
end
