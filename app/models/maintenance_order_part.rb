class MaintenanceOrderPart < ApplicationRecord
  SOURCES = %i[stock purchase].freeze

  belongs_to :tenant
  belongs_to :maintenance_order

  enum :source_type, SOURCES.index_with(&:to_s), validate: true

  monetize :unit_price_cents, :total_cents

  validates :description, presence: true
  validates :quantity, numericality: { greater_than: 0 }
end

# == Schema Information
#
# Table name: maintenance_order_parts
#
#  id                   :bigint           not null, primary key
#  code                 :string
#  description          :string           not null
#  document_number      :string
#  quantity             :decimal(12, 3)   not null
#  source_type          :enum             default("stock"), not null
#  total_cents          :bigint           default(0), not null
#  unit                 :string
#  unit_price_cents     :bigint           default(0), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  maintenance_order_id :bigint           not null
#  tenant_id            :bigint           not null
#
# Indexes
#
#  index_maintenance_order_parts_on_maintenance_order_id  (maintenance_order_id)
#  index_maintenance_order_parts_on_tenant_id             (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (maintenance_order_id => maintenance_orders.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
