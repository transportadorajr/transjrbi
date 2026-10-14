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
    has_one :empty_leg, class_name: 'EmptyLeg', foreign_key: %i[tenant_id next_manifest_code], primary_key: %i[tenant_id code],
                        inverse_of: :next_manifest

    monetize :goods_value_cents, allow_nil: true

    validates :code, presence: true, uniqueness: { scope: :tenant_id }
    validates :number, presence: true

    scope :by_period, ->(start_date, end_date) { where(issued_on: date_range(start_date, end_date)) }
    scope :by_period_start, ->(date) { by_period(date, nil) }
    scope :by_period_end, ->(date) { by_period(nil, date) }
    scope :by_number, ->(number) { where(number: number.to_s.strip) }
    scope :by_departure_period, ->(start_date, end_date) { where(departure_on: date_range(start_date, end_date)) }
    scope :by_plate, ->(plate) { where(plate: normalize_plate(plate)) }
    scope :by_status, ->(status) { where(status:) }
    scope :not_canceled, -> { where.not(status: CANCELED_STATUS).or(where(status: nil)) }
    scope :canceled, -> { where(status: CANCELED_STATUS) }
    scope :by_situation, ->(situation) { situation.to_s == 'canceled' ? canceled : not_canceled }
    scope :trips, -> { active.not_canceled.where.not(plate: [nil, '']) }

    class << self
      def trip_at
        Arel::Nodes::NamedFunction.new('COALESCE', [arel_table[:trip_started_at], arel_table[:departure_on], arel_table[:issued_on]])
      end

      def statuses
        {
          I18n.t('tax.situations.valid') => :valid,
          I18n.t('tax.situations.canceled') => :canceled,
        }
      end
    end

    def canceled?
      status == CANCELED_STATUS
    end

    def trip_on
      trip_started_at&.to_date || departure_on || issued_on
    end

    def trip?
      active? && !canceled? && plate.present?
    end

    def previous_trip
      trip_at = self.class.trip_at
      started_at = self.class.where(id:).pick(trip_at)
      before = trip_at.lt(started_at).or(trip_at.eq(started_at).and(self.class.arel_table[:code].lt(code)))

      self.class.trips.where(tenant_id:, plate:).where(before).order(trip_at.desc, code: :desc).first
    end

    def ordered_documents
      documents.active.preload(transport_document: %i[sender recipient]).to_a
        .reject { |document| document.transport_document&.canceled_at }
        .sort_by { |document| [document.transport_document&.issued_at.to_i, document.id] }
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
