class MaintenanceOrderLabor < ApplicationRecord
  belongs_to :tenant
  belongs_to :maintenance_order
  belongs_to :workshop_employee

  validates :worked_on, presence: true
  validates :hours, numericality: { greater_than: 0 }, allow_nil: true
end

# == Schema Information
#
# Table name: maintenance_order_labors
#
#  id                   :bigint           not null, primary key
#  activity             :text
#  end_time             :time
#  hours                :decimal(6, 2)
#  start_time           :time
#  worked_on            :date             not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  maintenance_order_id :bigint           not null
#  tenant_id            :bigint           not null
#  workshop_employee_id :bigint           not null
#
# Indexes
#
#  index_maintenance_order_labors_on_maintenance_order_id  (maintenance_order_id)
#  index_maintenance_order_labors_on_tenant_id             (tenant_id)
#  index_maintenance_order_labors_on_workshop_employee_id  (workshop_employee_id)
#
# Foreign Keys
#
#  fk_rails_...  (maintenance_order_id => maintenance_orders.id)
#  fk_rails_...  (tenant_id => tenants.id)
#  fk_rails_...  (workshop_employee_id => workshop_employees.id)
#
