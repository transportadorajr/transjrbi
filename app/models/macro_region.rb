class MacroRegion < ApplicationRecord
  include Sortable

  OTHERS = 'others'.freeze
  BRAZILIAN_STATES = %w[AC AL AM AP BA CE DF ES GO MA MG MS MT PA PB PE PI PR RJ RN RO RR RS SC SE SP TO].freeze

  sortable :name

  belongs_to :tenant
  has_many :transport_documents, class_name: 'Atua::TransportDocument', foreign_key: :origin_macro_region_id,
                                 inverse_of: :origin_macro_region, dependent: :nullify
  has_many :cities, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :tenant_id }
  validates :state, format: { with: /\A[A-Z]{2}\z/ }

  scope :by_name, ->(name) { where(arel_table[:name].matches("%#{sanitize_sql_like(name)}%")) }

  class << self
    def unassigned_origins(tenant)
      tenant.atua_transport_documents.active.freights.where(origin_macro_region_id: nil).where.not(origin_city: [nil, ''])
        .group(:origin_city, :origin_state).count.sort_by { |(city, state), count| [-count, state.to_s, city] }
    end

    def for_origin(regions, city, state)
      same_state = regions.select { |region| region.state == state.to_s.strip.upcase }

      same_state.find { |region| region.covers_city?(city) } || same_state.find(&:remaining_state?)
    end
  end

  def covers_city?(city)
    compacted_city = CustomerGroup.compact(city)

    compacted_city.present? && cities.any? { |region_city| region_city.compacted_name == compacted_city }
  end
end

# == Schema Information
#
# Table name: macro_regions
#
#  id              :bigint           not null, primary key
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
