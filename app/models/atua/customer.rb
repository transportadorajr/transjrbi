module Atua
  class Customer < ApplicationRecord
    include Importable

    with_options class_name: 'Atua::TransportDocument', primary_key: %i[tenant_id code], inverse_of: false do
      has_many :sent_transport_documents, foreign_key: %i[tenant_id sender_code]
      has_many :received_transport_documents, foreign_key: %i[tenant_id recipient_code]
      has_many :paid_transport_documents, foreign_key: %i[tenant_id payer_code]
      has_many :taken_transport_documents, foreign_key: %i[tenant_id taker_code]
      has_many :consigned_transport_documents, foreign_key: %i[tenant_id consignee_code]
    end
    has_many :expenses, class_name: 'Atua::Expense', foreign_key: %i[tenant_id payee_code], primary_key: %i[tenant_id code],
                        inverse_of: :payee

    validates :code, presence: true, uniqueness: { scope: :tenant_id }

    scope :by_name, ->(name) {
      pattern = "%#{sanitize_sql_like(name)}%"
      where(arel_table[:name].matches(pattern)).or(where(arel_table[:trade_name].matches(pattern)))
    }
    scope :by_document, ->(document) { where(document_digits: document.to_s.gsub(/\D/, '')) }
    scope :by_city, ->(city) { where(arel_table[:city].matches("%#{sanitize_sql_like(city.to_s.strip)}%")) }
  end
end

# == Schema Information
#
# Table name: atua_customers
#
#  id                   :bigint           not null, primary key
#  activity             :string
#  city                 :string
#  city_code            :bigint
#  code                 :bigint           not null
#  complement           :string
#  district             :string
#  document             :string
#  document_digits      :string
#  emails               :string           default([]), not null, is an Array
#  exporter_at          :datetime
#  imported_at          :datetime         not null
#  last_billed_on       :date
#  name                 :string
#  payment_method       :string
#  payment_term         :string
#  person_kind          :string
#  phone                :string
#  raw_data             :jsonb            not null
#  registered_on        :date
#  removed_from_atua_at :datetime
#  simples_optant_at    :datetime
#  state                :string
#  state_code           :bigint
#  state_registration   :string
#  status               :string
#  street               :string
#  trade_name           :string
#  updated_month_on     :date
#  whatsapp_at          :datetime
#  zip_code             :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  atua_import_id       :bigint
#  tenant_id            :bigint           not null
#
# Indexes
#
#  index_atua_customers_on_atua_import_id                 (atua_import_id)
#  index_atua_customers_on_tenant_id_and_code             (tenant_id,code) UNIQUE
#  index_atua_customers_on_tenant_id_and_document_digits  (tenant_id,document_digits)
#  index_atua_customers_on_tenant_id_and_status           (tenant_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (atua_import_id => atua_imports.id) ON DELETE => nullify
#  fk_rails_...  (tenant_id => tenants.id)
#
