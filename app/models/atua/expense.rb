module Atua
  class Expense < ApplicationRecord
    include Importable

    ALLOCATION_TYPES = {
      'freight' => 'Atua::TransportDocument',
      'vehicle' => 'Atua::Vehicle',
      'overhead' => nil,
    }.freeze
    UNLOADING_HISTORY_CODES = [72, 474].freeze
    UNLOADING_DOCUMENT_NUMBER = /\A\s*(\d{3,7})(?:\.0)?\s*(?:-?\s*(?:chapa\s+guia|guia|chapa))?\s*\z/i

    belongs_to :cost_object, polymorphic: true, optional: true
    belongs_to :vehicle, class_name: 'Atua::Vehicle', foreign_key: %i[tenant_id plate], primary_key: %i[tenant_id plate],
                         optional: true, inverse_of: false
    belongs_to :payee, class_name: 'Atua::Customer', foreign_key: %i[tenant_id payee_code], primary_key: %i[tenant_id code],
                       optional: true, inverse_of: :expenses

    monetize :amount_cents, :discount_cents, :total_cents, :net_amount_cents, :pis_credit_cents, :cofins_credit_cents,
             :withholdings_cents, :paid_cents, :icms_cents, :icms_credit_cents, allow_nil: true

    validates :code, presence: true, uniqueness: { scope: :tenant_id }

    scope :by_period, ->(start_date, end_date) { where(posted_on: date_range(start_date, end_date)) }
    scope :freight, -> { where(cost_object_type: ALLOCATION_TYPES['freight']) }
    scope :by_allocation, ->(allocation) {
      ALLOCATION_TYPES.key?(allocation.to_s) ? where(cost_object_type: ALLOCATION_TYPES[allocation.to_s]) : all
    }
    scope :by_plate, ->(plate) {
      plate = normalize_plate(plate)
      where(plate:).or(freight.where(cost_object_id: TransportDocument.by_plate(plate).select(:id)))
    }
    scope :by_vehicle, ->(vehicle) {
      where(cost_object: vehicle).or(freight.where(cost_object_id: TransportDocument.by_vehicle(vehicle).select(:id)))
    }
    scope :by_manifest, ->(manifest) {
      freight.where(cost_object_id: manifest.transport_documents.merge(ManifestDocument.active).select(TransportDocument.arel_table[:id]))
    }
    scope :by_period_start, ->(date) { by_period(date, nil) }
    scope :by_period_end, ->(date) { by_period(nil, date) }
    scope :by_payee, ->(code) { where(payee_code: code) }
    scope :by_payee_name, ->(name) { where(arel_table[:payee_name].matches("%#{sanitize_sql_like(name.to_s.strip)}%")) }
    scope :by_history, ->(code) { where(history_code: code) }
    scope :by_trip, ->(number) { where(trip_number: number) }
    scope :by_branch, ->(code) { where(branch_code: code) }
    scope :by_headquarters, ->(name) { where(headquarters_name: name) }
    scope :unloading, -> { where(history_code: UNLOADING_HISTORY_CODES) }

    class << self
      def allocations
        ALLOCATION_TYPES.keys.index_by { |allocation| I18n.t("enums.atua/expense.allocation.#{allocation}") }
      end

      def total_by_allocation
        group(:cost_object_type).sum(:total_cents).to_h { |type, cents| [ALLOCATION_TYPES.key(type), Money.from_cents(cents)] }
      end

      def unloading_transport_document_number(history_code, document_number)
        return unless UNLOADING_HISTORY_CODES.include?(history_code)

        UNLOADING_DOCUMENT_NUMBER.match(document_number.to_s)&.captures&.first&.to_i
      end
    end

    def allocation
      ALLOCATION_TYPES.key(cost_object_type)
    end

    def allocation_name
      I18n.t("enums.atua/expense.allocation.#{allocation}")
    end
  end
end

# == Schema Information
#
# Table name: atua_expenses
#
#  id                        :bigint           not null, primary key
#  accounting_account        :string
#  accounting_classification :string
#  accounting_on             :date
#  amount_cents              :bigint
#  apportionment_count       :integer
#  attachment_at             :datetime
#  branch_code               :bigint
#  branch_name               :string
#  cash_account_name         :string
#  code                      :bigint           not null
#  cofins_credit_cents       :bigint
#  cost_object_type          :string
#  description               :string
#  discount_cents            :bigint
#  document_key              :string
#  document_model            :string
#  document_number           :string
#  document_on               :date
#  document_series           :string
#  headquarters_name         :string
#  history_code              :bigint
#  history_name              :string
#  icms_cents                :bigint
#  icms_credit_cents         :bigint
#  icms_credit_percentage    :decimal(7, 4)
#  imported_at               :datetime         not null
#  installment_count         :integer
#  movement_code             :bigint
#  movement_on               :date
#  net_amount_cents          :bigint
#  paid_cents                :bigint
#  payee_code                :bigint
#  payee_document            :string
#  payee_document_digits     :string
#  payee_name                :string
#  pis_credit_cents          :bigint
#  plate                     :string
#  posted_at                 :datetime
#  posted_on                 :date
#  raw_data                  :jsonb            not null
#  removed_from_atua_at      :datetime
#  settled_on                :date
#  spending_kind             :string
#  total_cents               :bigint
#  transport_document_code   :bigint
#  transport_document_number :string
#  transport_document_series :integer
#  trip_arrival_on           :date
#  trip_departure_on         :date
#  trip_driver_code          :bigint
#  trip_driver_name          :string
#  trip_expense_kind         :string
#  trip_number               :string
#  vehicle_model             :string
#  withholdings_cents        :bigint
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  atua_import_id            :bigint
#  cost_object_id            :bigint
#  tenant_id                 :bigint           not null
#
# Indexes
#
#  index_atua_expenses_on_atua_import_id                         (atua_import_id)
#  index_atua_expenses_on_cost_object                            (cost_object_type,cost_object_id)
#  index_atua_expenses_on_tenant_id_and_code                     (tenant_id,code) UNIQUE
#  index_atua_expenses_on_tenant_id_and_headquarters_name        (tenant_id,headquarters_name)
#  index_atua_expenses_on_tenant_id_and_history_code             (tenant_id,history_code)
#  index_atua_expenses_on_tenant_id_and_payee_code               (tenant_id,payee_code)
#  index_atua_expenses_on_tenant_id_and_plate                    (tenant_id,plate)
#  index_atua_expenses_on_tenant_id_and_posted_on                (tenant_id,posted_on)
#  index_atua_expenses_on_tenant_id_and_transport_document_code  (tenant_id,transport_document_code)
#  index_atua_expenses_on_tenant_id_and_trip_number              (tenant_id,trip_number)
#
# Foreign Keys
#
#  fk_rails_...  (atua_import_id => atua_imports.id) ON DELETE => nullify
#  fk_rails_...  (tenant_id => tenants.id)
#
