class ExcludedDriver < ApplicationRecord
  belongs_to :tenant

  validates :code, presence: true, uniqueness: { scope: :tenant_id }
end

# == Schema Information
#
# Table name: excluded_drivers
#
#  id         :bigint           not null, primary key
#  code       :bigint           not null
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  tenant_id  :bigint           not null
#
# Indexes
#
#  index_excluded_drivers_on_tenant_id           (tenant_id)
#  index_excluded_drivers_on_tenant_id_and_code  (tenant_id,code) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
