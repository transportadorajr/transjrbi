class MaintenancePart < ApplicationRecord
  include Sortable
  include MaintenanceCatalogItem

  UNITS = %w[UN PC JG CJ KIT PAR CX L ML GL BD LT FR TB KG G M M2 M3 RL].freeze

  sortable :unit_price, -> { arel_table[:unit_price_cents] }

  has_many :maintenance_order_parts, dependent: :restrict_with_error
  has_many :movements, class_name: 'MaintenancePartMovement', dependent: :restrict_with_error

  monetize :unit_price_cents
end

# == Schema Information
#
# Table name: maintenance_parts
#
#  id               :bigint           not null, primary key
#  active           :boolean          default(TRUE), not null
#  brand            :string
#  code             :string
#  description      :string           not null
#  quantity         :decimal(12, 3)   default(0.0), not null
#  unit             :string
#  unit_price_cents :bigint           default(0), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  tenant_id        :bigint           not null
#
# Indexes
#
#  index_maintenance_parts_on_tenant_id                  (tenant_id)
#  index_maintenance_parts_on_tenant_id_and_code         (tenant_id,code) UNIQUE WHERE (code IS NOT NULL)
#  index_maintenance_parts_on_tenant_id_and_description  (tenant_id,description) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
