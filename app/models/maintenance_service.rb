class MaintenanceService < ApplicationRecord
  include Sortable
  include MaintenanceCatalogItem

  sortable :price, -> { arel_table[:price_cents] }

  has_many :maintenance_order_services, dependent: :restrict_with_error

  monetize :price_cents
end

# == Schema Information
#
# Table name: maintenance_services
#
#  id          :bigint           not null, primary key
#  active      :boolean          default(TRUE), not null
#  code        :string
#  description :string           not null
#  price_cents :bigint           default(0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  tenant_id   :bigint           not null
#
# Indexes
#
#  index_maintenance_services_on_tenant_id                  (tenant_id)
#  index_maintenance_services_on_tenant_id_and_code         (tenant_id,code) UNIQUE WHERE (code IS NOT NULL)
#  index_maintenance_services_on_tenant_id_and_description  (tenant_id,description) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
