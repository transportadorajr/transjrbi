class EmptyLegTransportDocument < ApplicationRecord
  belongs_to :empty_leg
  belongs_to :tenant
  belongs_to :transport_document, class_name: 'Atua::TransportDocument', foreign_key: %i[tenant_id transport_document_code],
                                  primary_key: %i[tenant_id code], optional: true, inverse_of: :empty_leg_transport_documents

  validates :transport_document_code, presence: true, uniqueness: { scope: :empty_leg_id }
end

# == Schema Information
#
# Table name: empty_leg_transport_documents
#
#  id                      :bigint           not null, primary key
#  transport_document_code :bigint           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  empty_leg_id            :bigint           not null
#  tenant_id               :bigint           not null
#
# Indexes
#
#  idx_on_empty_leg_id_transport_document_code_3c223e12fa  (empty_leg_id,transport_document_code) UNIQUE
#  idx_on_tenant_id_transport_document_code_eeccd5d4d4     (tenant_id,transport_document_code)
#
# Foreign Keys
#
#  fk_rails_...  (empty_leg_id => empty_legs.id) ON DELETE => cascade
#  fk_rails_...  (tenant_id => tenants.id)
#
