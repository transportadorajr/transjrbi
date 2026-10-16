class TonnageRate < ApplicationRecord
  WEIGHT_KG_ABOVE = 200
  OUTDATED_MONTHS = 2

  belongs_to :tenant
  belongs_to :customer_group, inverse_of: :tonnage_rates
  has_many :freight_expenses, dependent: :restrict_with_error, inverse_of: :tonnage_rate

  monetize :rate_cents

  time_based_flag :activated

  validates :name, :origin_city, :origin_state, :valid_month, presence: true
  validates :rate_cents, numericality: { greater_than: 0 }

  scope :by_name, ->(name) { where(arel_table[:name].matches("%#{sanitize_sql_like(name)}%")) }
  scope :by_customer_group, ->(customer_group_id) { where(customer_group_id:) }
  scope :by_valid_month, ->(month) { where(valid_month: parse_month(month)) }
  scope :by_status, ->(status) { status.to_s == 'active' ? activated : not_activated }

  class << self
    def statuses
      {
        I18n.t('tonnage_rates.index.active') => :active,
        I18n.t('tonnage_rates.index.deactivated') => :deactivated,
      }
    end

    def parse_month(value)
      Date.strptime("#{value.to_s.strip.first(7)}-01", '%Y-%m-%d')
    rescue Date::Error
      nil
    end

    def origin_key(city, state)
      [CustomerGroup.compact(city), CustomerGroup.compact(state)]
    end

    def weight_in_tons(weight_tons, weight_kg)
      weight = weight_tons.to_d
      return (weight > WEIGHT_KG_ABOVE ? weight / 1000 : weight).round(3) if weight.positive?

      (weight_kg.to_d / 1000).round(3) if weight_kg.to_d.positive?
    end

    def for_month(rates, month)
      rates.select { |rate| rate.valid_month <= month }.max_by(&:valid_month) || rates.min_by(&:valid_month)
    end

    def covered_documents(tenant)
      tenant.atua_transport_documents.active.not_canceled.joins(:taker)
        .where(atua_customers: { customer_group_id: tenant.tonnage_rates.activated.select(:customer_group_id) })
    end

    def missing_weight_documents(tenant)
      keys = tenant.tonnage_rates.activated.to_set(&:series_key)

      covered_documents(tenant).select('atua_transport_documents.*', Atua::Customer.arel_table[:customer_group_id])
        .where(weight_tons: [nil, 0], weight_kg: [nil, 0])
        .where(Atua::TransportDocument.arel_table[:issue_kind].is_distinct_from(Atua::TransportDocument::VALUE_COMPLEMENT))
        .select { |document| keys.include?([document.customer_group_id, *origin_key(document.origin_city, document.origin_state)]) }
    end

    def outdated(tenant)
      limit = Date.current.beginning_of_month.months_ago(OUTDATED_MONTHS - 1)

      tenant.tonnage_rates.activated.preload(:customer_group).group_by(&:series_key).values
        .map { |rates| rates.max_by(&:valid_month) }.select { |rate| rate.valid_month < limit }
        .sort_by { |rate| [rate.name, rate.origin_city] }
    end
  end

  def series_key
    [customer_group_id, *self.class.origin_key(origin_city, origin_state)]
  end

  def reference_month
    valid_month&.prev_month
  end

  def amount_cents(weight_tons)
    (weight_tons.to_d * rate_cents).round(0, BigDecimal::ROUND_HALF_UP).to_i
  end
end

# == Schema Information
#
# Table name: tonnage_rates
#
#  id                :bigint           not null, primary key
#  activated_at      :datetime
#  name              :string           not null
#  nickname          :string
#  origin_city       :string           not null
#  origin_state      :string           not null
#  rate_cents        :bigint           not null
#  valid_month       :date             not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  customer_group_id :bigint           not null
#  tenant_id         :bigint           not null
#
# Indexes
#
#  index_tonnage_rates_on_customer_group_id          (customer_group_id)
#  index_tonnage_rates_on_tenant_id                  (tenant_id)
#  index_tonnage_rates_on_tenant_id_and_valid_month  (tenant_id,valid_month)
#
# Foreign Keys
#
#  fk_rails_...  (customer_group_id => customer_groups.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
