class FreightExpense < ApplicationRecord
  KINDS = %i[commission].freeze

  belongs_to :tenant
  belongs_to :transport_document, class_name: 'Atua::TransportDocument', inverse_of: :freight_expenses
  belongs_to :commission_rule, optional: true, inverse_of: :freight_expenses

  enum :kind_type, KINDS.index_with(&:to_s), validate: true

  monetize :base_cents, :icms_cents, :amount_cents

  validates :percentage, :calculated_at, presence: true
  validates :commission_rule, presence: true, if: :commission?
  validates :kind_type, uniqueness: { scope: :transport_document_id }

  scope :by_period, ->(start_date, end_date) {
    joins(:transport_document).merge(Atua::TransportDocument.by_period(start_date, end_date))
  }
  scope :by_period_start, ->(date) { by_period(date, nil) }
  scope :by_period_end, ->(date) { by_period(nil, date) }
  scope :by_transport_document_number, ->(number) { joins(:transport_document).merge(Atua::TransportDocument.by_number(number)) }
  scope :by_customer_group, ->(customer_group_id) { joins(:commission_rule).where(commission_rules: { customer_group_id: }) }
  scope :by_kind, ->(kind) { where(kind_type: kind) }

  class << self
    def kinds
      KINDS.index_by { |kind| human_enum_name(:kind_type, kind) }
    end
  end
end

# == Schema Information
#
# Table name: freight_expenses
#
#  id                    :bigint           not null, primary key
#  amount_cents          :bigint           not null
#  base_cents            :bigint           not null
#  calculated_at         :datetime         not null
#  icms_cents            :bigint           default(0), not null
#  kind_type             :enum             not null
#  percentage            :decimal(7, 4)    not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  commission_rule_id    :bigint
#  tenant_id             :bigint           not null
#  transport_document_id :bigint           not null
#
# Indexes
#
#  index_freight_expenses_on_commission_rule_id                   (commission_rule_id)
#  index_freight_expenses_on_tenant_id                            (tenant_id)
#  index_freight_expenses_on_transport_document_id_and_kind_type  (transport_document_id,kind_type) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (commission_rule_id => commission_rules.id)
#  fk_rails_...  (tenant_id => tenants.id)
#  fk_rails_...  (transport_document_id => atua_transport_documents.id)
#
