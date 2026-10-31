class MacroRegion < ApplicationRecord
  include Sortable

  OTHERS = 'others'.freeze

  sortable :name

  belongs_to :tenant
  has_many :transport_documents, class_name: 'Atua::TransportDocument', foreign_key: :origin_macro_region_id,
                                 inverse_of: :origin_macro_region, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :tenant_id }
  validates :state, format: { with: /\A[A-Z]{2}\z/ }

  scope :by_name, ->(name) { where(arel_table[:name].matches("%#{sanitize_sql_like(name)}%")) }

  class << self
    def for_origin(regions, city, state)
      same_state = regions.select { |region| region.state == state.to_s.strip.upcase }

      same_state.find { |region| region.covers_city?(city) } || same_state.find(&:remaining_state?)
    end
  end

  def covers_city?(city)
    compacted_city = CustomerGroup.compact(city)

    compacted_city.present? && cities.any? { |region_city| CustomerGroup.compact(region_city) == compacted_city }
  end
end

# == Schema Information
#
# Table name: macro_regions
#
#  id              :bigint           not null, primary key
#  cities          :string           default([]), not null, is an Array
#  name            :string           not null
#  remaining_state :boolean          default(FALSE), not null
#  state           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  tenant_id       :bigint           not null
#
# Indexes
#
#  index_macro_regions_on_remaining_state     (tenant_id,state) UNIQUE WHERE remaining_state
#  index_macro_regions_on_tenant_id           (tenant_id)
#  index_macro_regions_on_tenant_id_and_name  (tenant_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
