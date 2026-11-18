class ExportPlant < ApplicationRecord
  include Activatable
  include Sortable
  include Exportable

  FEATURE = :export_summary

  export_field(:customer_group) { |plant| plant.customer_group.name }

  sortable :name

  belongs_to :tenant
  belongs_to :customer_group, inverse_of: :export_plants

  validates :name, presence: true, uniqueness: { scope: %i[tenant_id customer_group_id] }

  scope :by_name, ->(name) { where(arel_table[:name].matches("%#{sanitize_sql_like(name)}%")) }
  scope :by_customer_group, ->(customer_group_id) { where(customer_group_id:) }

  class << self
    def enabled?(tenant)
      Flipper.enabled?(FEATURE, tenant)
    end

    def statuses
      {
        I18n.t('export_plants.index.active') => :active,
        I18n.t('export_plants.index.deactivated') => :deactivated,
      }
    end
  end

  def serves_city?(city)
    compacted_city = CustomerGroup.compact(city)

    compacted_city.present? && compacted_cities.include?(compacted_city)
  end

  def compacted_cities
    cities.map { |city| CustomerGroup.compact(city) }.compact_blank
  end
end

# == Schema Information
#
# Table name: export_plants
#
#  id                :bigint           not null, primary key
#  activated_at      :datetime
#  cities            :string           default([]), not null, is an Array
#  name              :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  customer_group_id :bigint           not null
#  tenant_id         :bigint           not null
#
# Indexes
#
#  idx_on_tenant_id_customer_group_id_name_f57016730f  (tenant_id,customer_group_id,name) UNIQUE
#  index_export_plants_on_customer_group_id            (customer_group_id)
#  index_export_plants_on_tenant_id                    (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (customer_group_id => customer_groups.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
