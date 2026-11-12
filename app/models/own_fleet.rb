class OwnFleet < ApplicationRecord
  INTERNATIONAL_BILLING_PLATES = %w[INT6R00].freeze

  belongs_to :tenant

  validates :tenant_id, uniqueness: true

  def third_party?(plate)
    normalized = Atua::TransportDocument.normalize_plate(plate)

    plates.any? && normalized.present? && INTERNATIONAL_BILLING_PLATES.exclude?(normalized) && plates.exclude?(normalized)
  end
end

# == Schema Information
#
# Table name: own_fleets
#
#  id         :bigint           not null, primary key
#  plates     :string           default([]), not null, is an Array
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  tenant_id  :bigint           not null
#
# Indexes
#
#  index_own_fleets_on_tenant_id  (tenant_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
