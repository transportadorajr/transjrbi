class MaintenancePartMovement < ApplicationRecord
  TYPES = %i[entry exit adjustment].freeze

  belongs_to :tenant
  belongs_to :maintenance_part
  belongs_to :supplier, optional: true
  belongs_to :maintenance_order, optional: true
  belongs_to :maintenance_order_part, optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  enum :movement_type, TYPES.index_with(&:to_s), validate: true

  monetize :unit_cost_cents, allow_nil: true

  validates :moved_on, :quantity, :balance, presence: true

  scope :by_maintenance_part, ->(id) { where(maintenance_part_id: id) }
  scope :by_movement_type, ->(type) { TYPES.include?(type.to_s.to_sym) ? where(movement_type: type) : all }
  scope :by_period_start, ->(date) { where(moved_on: date..) }
  scope :by_period_end, ->(date) { where(moved_on: ..date) }
end

# == Schema Information
#
# Table name: maintenance_part_movements
#
#  id                        :bigint           not null, primary key
#  balance                   :decimal(12, 3)   not null
#  invoice_number            :string
#  moved_on                  :date             not null
#  movement_type             :enum             not null
#  notes                     :text
#  quantity                  :decimal(12, 3)   not null
#  unit_cost_cents           :bigint
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  created_by_id             :bigint
#  maintenance_order_id      :bigint
#  maintenance_order_part_id :bigint
#  maintenance_part_id       :bigint           not null
#  supplier_id               :bigint
#  tenant_id                 :bigint           not null
#
# Indexes
#
#  idx_on_maintenance_part_id_moved_on_794c290293                 (maintenance_part_id,moved_on)
#  index_maintenance_part_movements_on_created_by_id              (created_by_id)
#  index_maintenance_part_movements_on_maintenance_order_id       (maintenance_order_id)
#  index_maintenance_part_movements_on_maintenance_order_part_id  (maintenance_order_part_id) UNIQUE
#  index_maintenance_part_movements_on_maintenance_part_id        (maintenance_part_id)
#  index_maintenance_part_movements_on_supplier_id                (supplier_id)
#  index_maintenance_part_movements_on_tenant_id                  (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (maintenance_order_id => maintenance_orders.id)
#  fk_rails_...  (maintenance_order_part_id => maintenance_order_parts.id)
#  fk_rails_...  (maintenance_part_id => maintenance_parts.id)
#  fk_rails_...  (supplier_id => suppliers.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
