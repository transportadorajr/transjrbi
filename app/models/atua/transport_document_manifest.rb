module Atua
  class TransportDocumentManifest < ApplicationRecord
    include Importable

    belongs_to :transport_document, class_name: 'Atua::TransportDocument', foreign_key: %i[tenant_id transport_document_code],
                                    primary_key: %i[tenant_id code], optional: true, inverse_of: :transport_document_manifests
    belongs_to :manifest, class_name: 'Atua::Manifest', foreign_key: %i[tenant_id manifest_number branch_name],
                          primary_key: %i[tenant_id number branch_name], optional: true,
                          inverse_of: :transport_document_manifests

    validates :transport_document_code, :manifest_number, presence: true
    validates :manifest_number, uniqueness: { scope: %i[tenant_id transport_document_code] }
  end
end

# == Schema Information
#
# Table name: atua_transport_document_manifests
#
#  id                      :bigint           not null, primary key
#  branch_name             :string
#  imported_at             :datetime         not null
#  manifest_number         :string           not null
#  raw_data                :jsonb            not null
#  removed_from_atua_at    :datetime
#  transport_document_code :bigint           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  atua_import_id          :bigint
#  tenant_id               :bigint           not null
#
# Indexes
#
#  index_atua_transport_document_manifests_on_atua_import_id  (atua_import_id)
#  index_atua_transport_document_manifests_on_manifest        (tenant_id,manifest_number,branch_name)
#  index_atua_transport_document_manifests_on_source_key      (tenant_id,transport_document_code,manifest_number) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (atua_import_id => atua_imports.id) ON DELETE => nullify
#  fk_rails_...  (tenant_id => tenants.id)
#
