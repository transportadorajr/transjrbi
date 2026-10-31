module Atua
  class TollVoucher < ApplicationRecord
    include Importable

    belongs_to :transport_document, class_name: 'Atua::TransportDocument', foreign_key: %i[tenant_id transport_document_number branch_code],
                                    primary_key: %i[tenant_id number branch_code], optional: true, inverse_of: :toll_vouchers

    monetize :toll_cents, :charged_toll_cents, :advance_cents, :admin_fee_cents, :total_cents, allow_nil: true

    validates :code, presence: true, uniqueness: { scope: :tenant_id }
    validates :transport_document_number, presence: true

    scope :by_period, ->(start_date, end_date) { where(issued_on: date_range(start_date, end_date)) }
    scope :not_canceled, -> { where(canceled_on: nil) }
  end
end

# == Schema Information
#
# Table name: atua_toll_vouchers
#
#  id                        :bigint           not null, primary key
#  admin_fee_cents           :bigint
#  advance_cents             :bigint
#  axles                     :integer
#  branch_code               :bigint
#  branch_name               :string
#  canceled_on               :date
#  charged_toll_cents        :bigint
#  code                      :string           not null
#  document_kind             :string
#  driver_name               :string
#  imported_at               :datetime         not null
#  issued_on                 :date
#  issuer_code               :bigint
#  issuer_name               :string
#  order_number              :string
#  ordered_on                :date
#  payer_document            :string
#  payer_document_digits     :string
#  payer_name                :string
#  plate                     :string
#  posted_at                 :datetime
#  raw_data                  :jsonb            not null
#  removed_from_atua_at      :datetime
#  toll_cents                :bigint
#  total_cents               :bigint
#  transport_document_number :string           not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  atua_import_id            :bigint
#  tenant_id                 :bigint           not null
#
# Indexes
#
#  idx_on_tenant_id_transport_document_number_branch_c_7fe7b70ba2  (tenant_id,transport_document_number,branch_code)
#  index_atua_toll_vouchers_on_atua_import_id                      (atua_import_id)
#  index_atua_toll_vouchers_on_tenant_id_and_code                  (tenant_id,code) UNIQUE
#  index_atua_toll_vouchers_on_tenant_id_and_issued_on             (tenant_id,issued_on)
#
# Foreign Keys
#
#  fk_rails_...  (atua_import_id => atua_imports.id) ON DELETE => nullify
#  fk_rails_...  (tenant_id => tenants.id)
#
