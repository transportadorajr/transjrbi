module Atua
  class ManifestDocument < ApplicationRecord
    include Importable

    belongs_to :manifest, class_name: 'Atua::Manifest', foreign_key: %i[tenant_id manifest_code], primary_key: %i[tenant_id code],
                          optional: true, inverse_of: :documents
    belongs_to :transport_document, class_name: 'Atua::TransportDocument',
                                    foreign_key: %i[tenant_id transport_document_number transport_document_series branch_name],
                                    primary_key: %i[tenant_id number series branch_name], optional: true,
                                    inverse_of: :manifest_documents

    monetize :goods_value_cents, :freight_cents, allow_nil: true

    validates :manifest_code, :transport_document_number, presence: true
    validates :transport_document_number, uniqueness: { scope: %i[tenant_id manifest_code transport_document_series] }
  end
end

# == Schema Information
#
# Table name: atua_manifest_documents
#
#  id                        :bigint           not null, primary key
#  branch_name               :string
#  calculated_distance_km    :decimal(14, 2)
#  destination_city          :string
#  destination_state         :string
#  document_distance_km      :decimal(14, 2)
#  freight_cents             :bigint
#  freight_payment           :string
#  goods_invoice_numbers     :string           default([]), not null, is an Array
#  goods_value_cents         :bigint
#  imported_at               :datetime         not null
#  manifest_code             :bigint           not null
#  origin_agency_name        :string
#  origin_city               :string
#  origin_state              :string
#  raw_data                  :jsonb            not null
#  recipient_name            :string
#  removed_from_atua_at      :datetime
#  sender_name               :string
#  transport_document_number :string           not null
#  transport_document_series :integer
#  weight_kg                 :decimal(14, 2)
#  weight_tons               :decimal(14, 3)
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  atua_import_id            :bigint
#  tenant_id                 :bigint           not null
#
# Indexes
#
#  index_atua_manifest_documents_on_atua_import_id      (atua_import_id)
#  index_atua_manifest_documents_on_source_key          (tenant_id,manifest_code,transport_document_number,transport_document_series) UNIQUE
#  index_atua_manifest_documents_on_transport_document  (tenant_id,transport_document_number,transport_document_series,branch_name)
#
# Foreign Keys
#
#  fk_rails_...  (atua_import_id => atua_imports.id) ON DELETE => nullify
#  fk_rails_...  (tenant_id => tenants.id)
#
