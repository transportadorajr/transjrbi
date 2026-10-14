module Atua
  class TransportDocument < ApplicationRecord
    include Importable

    with_options class_name: 'Atua::Customer', primary_key: %i[tenant_id code], optional: true, inverse_of: false do
      belongs_to :sender, foreign_key: %i[tenant_id sender_code]
      belongs_to :recipient, foreign_key: %i[tenant_id recipient_code]
      belongs_to :payer, foreign_key: %i[tenant_id payer_code]
      belongs_to :taker, foreign_key: %i[tenant_id taker_code]
      belongs_to :consignee, foreign_key: %i[tenant_id consignee_code]
    end
    with_options class_name: 'Atua::Vehicle', optional: true do
      belongs_to :vehicle, foreign_key: %i[tenant_id vehicle_code], primary_key: %i[tenant_id code], inverse_of: :transport_documents
      belongs_to :trailer, foreign_key: %i[tenant_id trailer_plate], primary_key: %i[tenant_id plate],
                           inverse_of: :trailer_transport_documents
    end

    has_many :transport_document_manifests, class_name: 'Atua::TransportDocumentManifest',
                                            foreign_key: %i[tenant_id transport_document_code], primary_key: %i[tenant_id code],
                                            inverse_of: :transport_document
    has_many :manifests, through: :transport_document_manifests
    has_many :manifest_documents, class_name: 'Atua::ManifestDocument',
                                  foreign_key: %i[tenant_id transport_document_number transport_document_series branch_name],
                                  primary_key: %i[tenant_id number series branch_name], inverse_of: :transport_document
    has_many :expenses, class_name: 'Atua::Expense', foreign_key: %i[tenant_id transport_document_code],
                        primary_key: %i[tenant_id code], inverse_of: :transport_document
    has_many :empty_leg_transport_documents, foreign_key: %i[tenant_id transport_document_code], primary_key: %i[tenant_id code],
                                             inverse_of: :transport_document
    has_many :empty_legs, through: :empty_leg_transport_documents

    monetize :goods_value_cents, :freight_cents, :weight_freight_cents, :value_freight_cents, :ad_valorem_cents,
             :other_charges_cents, :toll_cents, :icms_base_cents, :icms_cents, :icms_st_cents, :federal_tax_cents,
             :ibs_cents, :cbs_cents, :result_cents, :driver_freight_cents, :advance_cents, :commission_cents,
             :insurance_cents, :cost_cents, allow_nil: true

    validates :code, presence: true, uniqueness: { scope: :tenant_id }
    validates :number, presence: true

    scope :by_period, ->(start_date, end_date) { where(issued_at: time_range(start_date, end_date)) }
    scope :by_period_start, ->(date) { by_period(date, nil) }
    scope :by_period_end, ->(date) { by_period(nil, date) }
    scope :by_number, ->(number) { where(number: number.to_s.strip) }
    scope :by_plate, ->(plate) {
      plate = normalize_plate(plate)
      where(plate:).or(where(trailer_plate: plate))
    }
    scope :by_customer, ->(code) {
      where(sender_code: code).or(where(recipient_code: code)).or(where(payer_code: code))
        .or(where(taker_code: code)).or(where(consignee_code: code))
    }
    scope :by_payer, ->(code) { where(payer_code: code) }
    scope :by_branch, ->(code) { where(branch_code: code) }
    scope :not_canceled, -> { where(canceled_at: nil) }
    scope :canceled, -> { where.not(canceled_at: nil) }
    scope :by_situation, ->(situation) { situation.to_s == 'canceled' ? canceled : not_canceled }

    class << self
      def statuses
        {
          I18n.t('tax.situations.valid') => :valid,
          I18n.t('tax.situations.canceled') => :canceled,
        }
      end
    end

    def canceled?
      canceled_at.present?
    end
  end
end

# == Schema Information
#
# Table name: atua_transport_documents
#
#  id                        :bigint           not null, primary key
#  access_key                :string
#  ad_valorem_cents          :bigint
#  advance_cents             :bigint
#  agency_code               :bigint
#  agency_name               :string
#  arrival_on                :date
#  axles                     :integer
#  billing_number            :string
#  branch_code               :bigint
#  branch_name               :string
#  canceled_at               :datetime
#  cancellation_reason       :string
#  cargo_destination         :string
#  cbs_cents                 :bigint
#  cfop                      :integer
#  charged_at                :datetime
#  ciot                      :string
#  code                      :bigint           not null
#  commission_cents          :bigint
#  complemented_number       :string
#  consignee_code            :bigint
#  consignee_document        :string
#  consignee_document_digits :string
#  consignee_name            :string
#  cost_cents                :bigint
#  cte_status                :string
#  destination_city          :string
#  destination_city_code     :bigint
#  destination_state         :string
#  distance_km               :decimal(14, 2)
#  document_kind             :string
#  driver_code               :bigint
#  driver_document           :string
#  driver_document_digits    :string
#  driver_freight_cents      :bigint
#  driver_name               :string
#  due_on                    :date
#  federal_tax_cents         :bigint
#  freight_cents             :bigint
#  goods_invoice_keys        :string           default([]), not null, is an Array
#  goods_invoice_numbers     :string           default([]), not null, is an Array
#  goods_value_cents         :bigint
#  headquarters_code         :bigint
#  headquarters_name         :string
#  ibs_cents                 :bigint
#  icms_base_cents           :bigint
#  icms_cents                :bigint
#  icms_st_cents             :bigint
#  imported_at               :datetime         not null
#  insurance_cents           :bigint
#  issue_kind                :string
#  issued_at                 :datetime
#  manifest_numbers          :string           default([]), not null, is an Array
#  ncm                       :string
#  nfse_pending_at           :datetime
#  number                    :string           not null
#  operational_unit          :string
#  origin_city               :string
#  origin_city_code          :bigint
#  origin_state              :string
#  other_charges_cents       :bigint
#  payer_code                :bigint
#  payer_document            :string
#  payer_document_digits     :string
#  payer_name                :string
#  plate                     :string
#  posted_on                 :date
#  product_name              :string
#  product_quantity          :decimal(14, 3)
#  raw_data                  :jsonb            not null
#  recipient_code            :bigint
#  recipient_document        :string
#  recipient_document_digits :string
#  recipient_name            :string
#  removed_from_atua_at      :datetime
#  result_cents              :bigint
#  result_margin_percentage  :decimal(12, 4)
#  route                     :string
#  sender_code               :bigint
#  sender_document           :string
#  sender_document_digits    :string
#  sender_name               :string
#  series                    :integer
#  service_kind              :string
#  shipment_number           :string
#  taker_code                :bigint
#  taker_name                :string
#  toll_cents                :bigint
#  trailer_plate             :string
#  value_freight_cents       :bigint
#  vehicle_code              :bigint
#  vehicle_ownership         :string
#  weight_freight_cents      :bigint
#  weight_kg                 :decimal(14, 2)
#  weight_tons               :decimal(14, 3)
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  atua_import_id            :bigint
#  tenant_id                 :bigint           not null
#
# Indexes
#
#  idx_on_tenant_id_number_series_branch_name_82ba4806a5           (tenant_id,number,series,branch_name)
#  index_atua_transport_documents_on_atua_import_id                (atua_import_id)
#  index_atua_transport_documents_on_manifest_numbers              (manifest_numbers) USING gin
#  index_atua_transport_documents_on_tenant_id_and_code            (tenant_id,code) UNIQUE
#  index_atua_transport_documents_on_tenant_id_and_consignee_code  (tenant_id,consignee_code)
#  index_atua_transport_documents_on_tenant_id_and_cte_status      (tenant_id,cte_status)
#  index_atua_transport_documents_on_tenant_id_and_issued_at       (tenant_id,issued_at)
#  index_atua_transport_documents_on_tenant_id_and_payer_code      (tenant_id,payer_code)
#  index_atua_transport_documents_on_tenant_id_and_plate           (tenant_id,plate)
#  index_atua_transport_documents_on_tenant_id_and_posted_on       (tenant_id,posted_on)
#  index_atua_transport_documents_on_tenant_id_and_recipient_code  (tenant_id,recipient_code)
#  index_atua_transport_documents_on_tenant_id_and_sender_code     (tenant_id,sender_code)
#  index_atua_transport_documents_on_tenant_id_and_taker_code      (tenant_id,taker_code)
#  index_atua_transport_documents_on_tenant_id_and_trailer_plate   (tenant_id,trailer_plate)
#  index_atua_transport_documents_on_tenant_id_and_vehicle_code    (tenant_id,vehicle_code)
#
# Foreign Keys
#
#  fk_rails_...  (atua_import_id => atua_imports.id) ON DELETE => nullify
#  fk_rails_...  (tenant_id => tenants.id)
#
