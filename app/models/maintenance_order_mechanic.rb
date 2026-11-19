class MaintenanceOrderMechanic < ApplicationRecord
  belongs_to :tenant
  belongs_to :maintenance_order
  belongs_to :workshop_employee

  validates :workshop_employee_id, uniqueness: { scope: :maintenance_order_id }
end

# == Schema Information
#
# Table name: maintenance_order_mechanics
#
#  id                   :bigint           not null, primary key
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  maintenance_order_id :bigint           not null
#  tenant_id            :bigint           not null
#  workshop_employee_id :bigint           not null
#
# Indexes
#
#  index_maintenance_order_mechanics_on_maintenance_order_id  (maintenance_order_id)
#  index_maintenance_order_mechanics_on_tenant_id             (tenant_id)
#  index_maintenance_order_mechanics_on_workshop_employee_id  (workshop_employee_id)
#  index_maintenance_order_mechanics_uniqueness               (maintenance_order_id,workshop_employee_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (maintenance_order_id => maintenance_orders.id)
#  fk_rails_...  (tenant_id => tenants.id)
#  fk_rails_...  (workshop_employee_id => workshop_employees.id)
#
