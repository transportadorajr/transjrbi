class InsuranceRate < ApplicationRecord
  DEFAULT_INSURANCE_PERCENTAGE = BigDecimal('0.022')
  DEFAULT_IOF_PERCENTAGE = BigDecimal('7.38')

  belongs_to :tenant
  has_many :freight_expenses, dependent: :restrict_with_error, inverse_of: :insurance_rate

  validates :valid_from, presence: true, uniqueness: { scope: :tenant_id }
  validates :insurance_percentage, numericality: { greater_than: 0, less_than: 100 }
  validates :iof_percentage, numericality: { greater_than_or_equal_to: 0, less_than: 100 }

  scope :by_valid_from_start, ->(date) { where(valid_from: parse_date(date)..) }
  scope :by_valid_from_end, ->(date) { where(valid_from: ..parse_date(date)) }

  class << self
    def for_date(rates, date)
      rates.select { |rate| rate.valid_from <= date }.max_by(&:valid_from) || rates.min_by(&:valid_from)
    end

    def current(tenant)
      for_date(tenant.insurance_rates.order(:valid_from).to_a, Date.current)
    end

    def parse_date(value)
      Date.iso8601(value.to_s.strip)
    rescue Date::Error
      nil
    end
  end

  def insurance_cents(base_cents)
    percentage_of(base_cents, insurance_percentage)
  end

  def iof_cents(insurance_cents)
    percentage_of(insurance_cents, iof_percentage)
  end

  private

  def percentage_of(cents, percentage)
    (cents.to_d * percentage / 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
  end
end

# == Schema Information
#
# Table name: insurance_rates
#
#  id                   :bigint           not null, primary key
#  insurance_percentage :decimal(7, 4)    not null
#  iof_percentage       :decimal(7, 4)    not null
#  valid_from           :date             not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  tenant_id            :bigint           not null
#
# Indexes
#
#  index_insurance_rates_on_tenant_id                 (tenant_id)
#  index_insurance_rates_on_tenant_id_and_valid_from  (tenant_id,valid_from) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
