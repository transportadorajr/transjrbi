class MaintenanceOrderService < ApplicationRecord
  belongs_to :tenant
  belongs_to :maintenance_order
  belongs_to :supplier

  monetize :quoted_cents, :approved_cents, allow_nil: true

  validates :description, presence: true
end

# == Schema Information
#
# Table name: maintenance_order_services
#
#  id                   :bigint           not null, primary key
#  approved_by_name     :string
#  approved_cents       :bigint
#  description          :string           not null
#  invoice_number       :string
#  quote_number         :string
#  quoted_cents         :bigint
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  maintenance_order_id :bigint           not null
#  supplier_id          :bigint           not null
#  tenant_id            :bigint           not null
#
# Indexes
#
#  index_maintenance_order_services_on_maintenance_order_id  (maintenance_order_id)
#  index_maintenance_order_services_on_supplier_id           (supplier_id)
#  index_maintenance_order_services_on_tenant_id             (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (maintenance_order_id => maintenance_orders.id)
#  fk_rails_...  (supplier_id => suppliers.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
