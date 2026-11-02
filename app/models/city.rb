class City < ApplicationRecord
  include Sortable

  sortable :name
  sortable :state

  belongs_to :tenant
  belongs_to :macro_region, optional: true

  validates :name, presence: true, uniqueness: { scope: %i[tenant_id state] }
  validates :state, format: { with: /\A[A-Z]{2}\z/ }

  scope :by_name, ->(name) { where(arel_table[:name].matches("%#{sanitize_sql_like(name)}%")) }
  scope :by_state, ->(state) { where(state: state.to_s.strip.upcase) }
  scope :by_macro_region, ->(macro_region_id) {
    where(macro_region_id: macro_region_id.to_s == MacroRegion::OTHERS ? nil : macro_region_id)
  }

  def compacted_name
    CustomerGroup.compact(name)
  end
end

# == Schema Information
#
# Table name: cities
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  state           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  macro_region_id :bigint
#  tenant_id       :bigint           not null
#
# Indexes
#
#  index_cities_on_macro_region_id               (macro_region_id)
#  index_cities_on_tenant_id                     (tenant_id)
#  index_cities_on_tenant_id_and_state_and_name  (tenant_id,state,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (macro_region_id => macro_regions.id) ON DELETE => nullify
#  fk_rails_...  (tenant_id => tenants.id)
#
