class Supplier < ApplicationRecord
  include Sortable

  sortable :name

  belongs_to :tenant
  has_many :maintenance_order_services, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :tenant_id }

  scope :active, -> { where(active: true) }
  scope :by_name, ->(name) { where(arel_table[:name].matches("%#{sanitize_sql_like(name)}%")) }
end

# == Schema Information
#
# Table name: suppliers
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  document   :string
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  tenant_id  :bigint           not null
#
# Indexes
#
#  index_suppliers_on_tenant_id           (tenant_id)
#  index_suppliers_on_tenant_id_and_name  (tenant_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
