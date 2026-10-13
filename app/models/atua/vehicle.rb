module Atua
  class Vehicle < ApplicationRecord
    include Importable

    with_options primary_key: %i[tenant_id plate] do
      has_many :trailer_transport_documents, class_name: 'Atua::TransportDocument', foreign_key: %i[tenant_id trailer_plate],
                                             inverse_of: :trailer
      has_many :manifests, class_name: 'Atua::Manifest', foreign_key: %i[tenant_id plate], inverse_of: :vehicle
      has_many :expenses, class_name: 'Atua::Expense', foreign_key: %i[tenant_id plate], inverse_of: :vehicle
    end
    has_many :transport_documents, class_name: 'Atua::TransportDocument', foreign_key: %i[tenant_id vehicle_code],
                                   primary_key: %i[tenant_id code], inverse_of: :vehicle

    validates :code, presence: true, uniqueness: { scope: :tenant_id }

    scope :by_plate, ->(plate) { where(plate: normalize_plate(plate)) }
  end
end

# == Schema Information
#
# Table name: atua_vehicles
#
#  id                     :bigint           not null, primary key
#  antt                   :string
#  body                   :string
#  brand                  :string
#  brand_code             :bigint
#  category               :string
#  chassis                :string
#  city                   :string
#  city_code              :bigint
#  code                   :bigint           not null
#  color                  :string
#  data_expires_on        :date
#  driver_code            :bigint
#  driver_document        :string
#  driver_document_digits :string
#  driver_license         :string
#  driver_name            :string
#  driver_whatsapp_at     :datetime
#  high_performance_at    :datetime
#  imported_at            :datetime         not null
#  manufacture_year       :integer
#  model                  :string
#  model_year             :integer
#  owner_code             :bigint
#  owner_document         :string
#  owner_document_digits  :string
#  owner_name             :string
#  owner_whatsapp_at      :datetime
#  ownership              :string
#  plate                  :string
#  raw_data               :jsonb            not null
#  registered_month_on    :date
#  removed_from_atua_at   :datetime
#  renavam                :string
#  risk_status            :string
#  source_updated_at      :datetime
#  state                  :string
#  state_code             :bigint
#  status                 :string
#  updated_month_on       :date
#  vehicle_kind           :string
#  vehicle_kind_code      :bigint
#  wheelset               :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  atua_import_id         :bigint
#  tenant_id              :bigint           not null
#
# Indexes
#
#  index_atua_vehicles_on_atua_import_id            (atua_import_id)
#  index_atua_vehicles_on_tenant_id_and_code        (tenant_id,code) UNIQUE
#  index_atua_vehicles_on_tenant_id_and_owner_code  (tenant_id,owner_code)
#  index_atua_vehicles_on_tenant_id_and_plate       (tenant_id,plate)
#  index_atua_vehicles_on_tenant_id_and_status      (tenant_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (atua_import_id => atua_imports.id) ON DELETE => nullify
#  fk_rails_...  (tenant_id => tenants.id)
#
