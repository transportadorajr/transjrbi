module Atua
  class Expense < ApplicationRecord
    include Importable

    belongs_to :transport_document, class_name: 'Atua::TransportDocument', foreign_key: %i[tenant_id transport_document_code],
                                    primary_key: %i[tenant_id code], optional: true, inverse_of: :expenses
    belongs_to :vehicle, class_name: 'Atua::Vehicle', foreign_key: %i[tenant_id plate], primary_key: %i[tenant_id plate],
                         optional: true, inverse_of: :expenses
    belongs_to :payee, class_name: 'Atua::Customer', foreign_key: %i[tenant_id payee_code], primary_key: %i[tenant_id code],
                       optional: true, inverse_of: :expenses

    monetize :amount_cents, :discount_cents, :total_cents, :net_amount_cents, :pis_credit_cents, :cofins_credit_cents,
             :withholdings_cents, :paid_cents, :icms_cents, :icms_credit_cents, allow_nil: true

    validates :code, presence: true, uniqueness: { scope: :tenant_id }

    scope :by_period, ->(start_date, end_date) { where(posted_on: date_range(start_date, end_date)) }
    scope :by_plate, ->(plate) { where(plate: normalize_plate(plate)) }
    scope :by_payee, ->(code) { where(payee_code: code) }
    scope :by_history, ->(code) { where(history_code: code) }
    scope :by_trip, ->(number) { where(trip_number: number) }
    scope :by_branch, ->(code) { where(branch_code: code) }
    scope :by_headquarters, ->(name) { where(headquarters_name: name) }
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
#  tenant_id                 :bigint           not null
#
# Indexes
#
#  index_atua_expenses_on_atua_import_id                         (atua_import_id)
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
