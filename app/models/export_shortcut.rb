class ExportShortcut < ApplicationRecord
  include Activatable
  include Sortable
  include Exportable

  COUNTRIES = [*Atua::Customer::COUNTRIES.map(&:to_s), Dashboard::ExportFacts::UNKNOWN_COUNTRY].freeze

  export_field(:customer_group) { |shortcut| shortcut.customer_group&.name }
  export_field(:export_plants) { |shortcut| shortcut.export_plants.map(&:name).join(', ') }

  sortable :name

  belongs_to :tenant
  belongs_to :customer_group, optional: true, inverse_of: :export_shortcuts

  validates :name, presence: true, uniqueness: { scope: :tenant_id }

  scope :by_name, ->(name) { where(arel_table[:name].matches("%#{sanitize_sql_like(name)}%")) }
  scope :ordered, -> { order(:position, :name, :id) }

  class << self
    def statuses
      {
        I18n.t('export_shortcuts.index.active') => :active,
        I18n.t('export_shortcuts.index.deactivated') => :deactivated,
      }
    end
  end

  def export_plants
    tenant.export_plants.where(id: export_plant_ids).order(:name, :id)
  end

  def plant_keys
    export_plant_ids.map { |id| "#{Dashboard::ExportFacts::PLANT_PREFIX}-#{id}" }
  end

  def matches?(fact)
    (customer_group_id.nil? || fact.customer_group_id == customer_group_id) &&
      (export_plant_ids.empty? || plant_keys.include?(fact.plant_key)) &&
      (countries.empty? || countries.include?(fact.country))
  end
end

# == Schema Information
#
# Table name: export_shortcuts
#
#  id                :bigint           not null, primary key
#  activated_at      :datetime
#  countries         :string           default([]), not null, is an Array
#  export_plant_ids  :bigint           default([]), not null, is an Array
#  name              :string           not null
#  position          :integer          default(0), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  customer_group_id :bigint
#  tenant_id         :bigint           not null
#
# Indexes
#
#  index_export_shortcuts_on_customer_group_id   (customer_group_id)
#  index_export_shortcuts_on_tenant_id           (tenant_id)
#  index_export_shortcuts_on_tenant_id_and_name  (tenant_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (customer_group_id => customer_groups.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
