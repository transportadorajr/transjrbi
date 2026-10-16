class CommissionRule < ApplicationRecord
  FOREIGN_STATE = 'EX'.freeze
  DESTINATIONS = %i[national foreign].freeze
  BASES = %i[freight freight_without_icms].freeze

  belongs_to :tenant
  belongs_to :customer_group, inverse_of: :commission_rules
  has_many :freight_expenses, dependent: :restrict_with_error, inverse_of: :commission_rule

  enum :destination_type, DESTINATIONS.index_with(&:to_s), validate: true
  enum :base_type, BASES.index_with(&:to_s), prefix: :base, validate: true

  time_based_flag :activated

  validates :name, presence: true
  validates :percentage, numericality: { greater_than: 0, less_than: 100 }

  scope :by_name, ->(name) { where(arel_table[:name].matches("%#{sanitize_sql_like(name)}%")) }
  scope :by_customer_group, ->(customer_group_id) { where(customer_group_id:) }
  scope :by_status, ->(status) { status.to_s == 'active' ? activated : not_activated }

  class << self
    def statuses
      {
        I18n.t('commission_rules.index.active') => :active,
        I18n.t('commission_rules.index.deactivated') => :deactivated,
      }
    end

    def covered_documents(tenant)
      tenant.atua_transport_documents.commissionable.joins(:taker)
        .where(atua_customers: { customer_group_id: tenant.commission_rules.activated.select(:customer_group_id) })
    end

    def unmatched_foreign_documents(tenant)
      covered_documents(tenant).where(destination_state: FOREIGN_STATE)
        .where.not(id: tenant.freight_expenses.commission.select(:transport_document_id))
    end

    def foreign_destination?(state)
      state.to_s.strip.upcase == FOREIGN_STATE
    end

    def for_destination(rules, state, city)
      return rules.find(&:national?) unless foreign_destination?(state)

      rules.select(&:foreign?).find { |rule| rule.serves_city?(city) }
    end
  end

  def serves_city?(city)
    compacted_city = CustomerGroup.compact(city)

    compacted_city.present? && cities.any? { |rule_city| CustomerGroup.compact(rule_city) == compacted_city }
  end

  def deducted_icms_cents(icms_cents)
    base_freight_without_icms? ? icms_cents.to_i : 0
  end

  def amount_cents(base_cents)
    (base_cents * percentage / 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
  end
end

# == Schema Information
#
# Table name: commission_rules
#
#  id                :bigint           not null, primary key
#  activated_at      :datetime
#  base_type         :enum             not null
#  cities            :string           default([]), not null, is an Array
#  destination_type  :enum             not null
#  name              :string           not null
#  percentage        :decimal(7, 4)    not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  customer_group_id :bigint           not null
#  tenant_id         :bigint           not null
#
# Indexes
#
#  index_commission_rules_on_customer_group_id  (customer_group_id)
#  index_commission_rules_on_tenant_id          (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (customer_group_id => customer_groups.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
