class WorkshopEmployee < ApplicationRecord
  include Sortable

  ROLES = %i[mechanic supervisor].freeze

  sortable :name

  belongs_to :tenant
  has_many :supervised_maintenance_orders, class_name: 'MaintenanceOrder', foreign_key: :supervisor_id,
                                           inverse_of: :supervisor, dependent: :restrict_with_error
  has_many :maintenance_order_labors, dependent: :restrict_with_error

  enum :role_type, ROLES.index_with(&:to_s), validate: true

  validates :name, presence: true, uniqueness: { scope: :tenant_id }

  scope :active, -> { where(active: true) }
  scope :by_name, ->(name) { where(arel_table[:name].matches("%#{sanitize_sql_like(name)}%")) }
  scope :by_role_type, ->(role_type) { where(role_type:) }
end

# == Schema Information
#
# Table name: workshop_employees
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  name       :string           not null
#  role_type  :enum             default("mechanic"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  tenant_id  :bigint           not null
#
# Indexes
#
#  index_workshop_employees_on_tenant_id           (tenant_id)
#  index_workshop_employees_on_tenant_id_and_name  (tenant_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
