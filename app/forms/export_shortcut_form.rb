class ExportShortcutForm < BaseForm
  attribute :name, :string
  attribute :customer_group_id, :integer
  attribute :export_plant_ids, default: -> { [] }
  attribute :countries, default: -> { [] }
  attribute :position, :integer, default: 0
  attribute :active, :boolean, default: true

  before_validation :normalize_fields

  validates :name, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :name_must_be_unique
  validate :customer_group_must_belong_to_tenant
  validate :plants_must_belong_to_tenant_and_group
  validate :countries_must_be_known

  attr_accessor :tenant
  attr_writer :export_shortcut

  delegate :id, :persisted?, to: :export_shortcut

  class << self
    def for_export_shortcut(export_shortcut)
      form = new(name: export_shortcut.name, customer_group_id: export_shortcut.customer_group_id, export_plant_ids: export_shortcut.export_plant_ids,
                 countries: export_shortcut.countries, position: export_shortcut.position, active: export_shortcut.activated?,
                 tenant: export_shortcut.tenant)
      form.export_shortcut = export_shortcut
      form
    end
  end

  def export_shortcut
    @export_shortcut ||= tenant.export_shortcuts.new
  end

  def customer_groups
    tenant.customer_groups.order(:name, :id)
  end

  def export_plants
    tenant.export_plants.activated.preload(:customer_group).order(:name, :id)
  end

  def plant_id_list
    Array(export_plant_ids).compact_blank.map(&:to_i).uniq.sort
  end

  def country_list
    Array(countries).compact_blank.map(&:to_s).uniq
  end

  def submit
    export_shortcut.update!(name:, customer_group_id:, export_plant_ids: plant_id_list, countries: country_list, position:, activated: active)
  end

  private

  def normalize_fields
    self.name = name.to_s.squish
  end

  def name_must_be_unique
    shortcuts = tenant.export_shortcuts.where(ExportShortcut.arel_table[:name].matches(ExportShortcut.sanitize_sql_like(name)))
    shortcuts = shortcuts.where.not(id: export_shortcut.id) if persisted?

    errors.add(:name, :taken) if name.present? && shortcuts.exists?
  end

  def customer_group_must_belong_to_tenant
    return if customer_group_id.blank? || tenant.customer_groups.exists?(customer_group_id)

    errors.add(:customer_group_id, :invalid)
  end

  def plants_must_belong_to_tenant_and_group
    plants = tenant.export_plants.where(id: plant_id_list)
    plants = plants.where(customer_group_id:) if customer_group_id.present?

    errors.add(:export_plant_ids, :invalid) if plants.count != plant_id_list.size
  end

  def countries_must_be_known
    errors.add(:countries, :invalid) if (country_list - ExportShortcut::COUNTRIES).any?
  end
end
