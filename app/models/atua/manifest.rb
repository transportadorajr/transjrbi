module Atua
  class Manifest < ApplicationRecord
    include Importable

    CANCELED_STATUS = 'Cancelado'.freeze

    belongs_to :vehicle, class_name: 'Atua::Vehicle', foreign_key: %i[tenant_id plate], primary_key: %i[tenant_id plate],
                         optional: true, inverse_of: :manifests

    has_many :documents, class_name: 'Atua::ManifestDocument', foreign_key: %i[tenant_id manifest_code],
                         primary_key: %i[tenant_id code], inverse_of: :manifest
    has_many :transport_documents, through: :documents
    has_many :transport_document_manifests, class_name: 'Atua::TransportDocumentManifest',
                                            foreign_key: %i[tenant_id manifest_number branch_name],
                                            primary_key: %i[tenant_id number branch_name], inverse_of: :manifest

    monetize :goods_value_cents, allow_nil: true

    validates :code, presence: true, uniqueness: { scope: :tenant_id }
    validates :number, presence: true

    scope :by_period, ->(start_date, end_date) { where(issued_on: date_range(start_date, end_date)) }
    scope :by_departure_period, ->(start_date, end_date) { where(departure_on: date_range(start_date, end_date)) }
    scope :by_plate, ->(plate) { where(plate: normalize_plate(plate)) }
    scope :by_status, ->(status) { where(status:) }
    scope :not_canceled, -> { where.not(status: CANCELED_STATUS).or(where(status: nil)) }

    def canceled?
      status == CANCELED_STATUS
    end
  end
end

# == Schema Information
#
# Table name: atua_manifests
#
#  id                   :bigint           not null, primary key
#  access_key           :string
#  branch_name          :string
#  closed_at            :datetime
#  code                 :bigint           not null
#  company_city         :string
#  company_state        :string
#  departure_on         :date
#  goods_value_cents    :bigint
#  imported_at          :datetime         not null
#  issued_on            :date
#  model                :integer
#  notes                :text
#  number               :string           not null
#  plate                :string
#  raw_data             :jsonb            not null
#  removed_from_atua_at :datetime
#  series               :integer
#  status               :string
#  trip_started_at      :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  atua_import_id       :bigint
#  tenant_id            :bigint           not null
#
# Indexes
#
#  index_atua_manifests_on_atua_import_id                        (atua_import_id)
#  index_atua_manifests_on_tenant_id_and_code                    (tenant_id,code) UNIQUE
#  index_atua_manifests_on_tenant_id_and_departure_on            (tenant_id,departure_on)
#  index_atua_manifests_on_tenant_id_and_issued_on               (tenant_id,issued_on)
#  index_atua_manifests_on_tenant_id_and_number_and_branch_name  (tenant_id,number,branch_name)
#  index_atua_manifests_on_tenant_id_and_plate                   (tenant_id,plate)
#  index_atua_manifests_on_tenant_id_and_status                  (tenant_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (atua_import_id => atua_imports.id) ON DELETE => nullify
#  fk_rails_...  (tenant_id => tenants.id)
#
