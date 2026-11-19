class MaintenanceOrderItem < ApplicationRecord
  TYPES = %w[MaintenanceOrderPart MaintenanceOrderService].freeze

  belongs_to :tenant
  belongs_to :maintenance_order
  delegated_type :itemizable, types: TYPES, dependent: :destroy, autosave: true

  monetize :total_cents

  validates :description, presence: true

  before_validation :copy_shared_columns_to_itemizable
  before_create :assign_position

  scope :ordered, -> { order(:position, :id) }

  private

  def copy_shared_columns_to_itemizable
    return if itemizable.nil?

    itemizable.assign_attributes(tenant:, maintenance_order:, description:, notes:)
    itemizable.total_cents = total_cents if maintenance_order_part?
  end

  def assign_position
    return if position.positive?

    self.position = maintenance_order.items.maximum(:position).to_i + 1
  end
end

# == Schema Information
#
# Table name: maintenance_order_items
#
#  id                   :bigint           not null, primary key
#  description          :string           not null
#  itemizable_type      :string           not null
#  notes                :text
#  position             :integer          default(0), not null
#  total_cents          :bigint           default(0), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  itemizable_id        :bigint           not null
#  maintenance_order_id :bigint           not null
#  tenant_id            :bigint           not null
#
# Indexes
#
#  index_maintenance_order_items_on_itemizable          (itemizable_type,itemizable_id) UNIQUE
#  index_maintenance_order_items_on_order_and_position  (maintenance_order_id,position)
#  index_maintenance_order_items_on_tenant_id           (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (maintenance_order_id => maintenance_orders.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
