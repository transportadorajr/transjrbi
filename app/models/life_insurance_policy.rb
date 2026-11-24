class LifeInsurancePolicy < ApplicationRecord
  PER_MILLE = 1000
  PERCENT = 100

  belongs_to :tenant
  has_many :life_insurances, dependent: :restrict_with_error

  enum :company_type, Employee::COMPANIES.index_with(&:to_s), validate: true

  monetize :capital_cents, :funeral_assistance_cents

  validates :company_type, uniqueness: { scope: :tenant_id }
  validates :capital_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :funeral_assistance_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :premium_rate_per_mille, numericality: { greater_than: 0, less_than: PER_MILLE }
  validates :spouse_percentage, :children_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: PERCENT }

  scope :by_company_type, ->(company_type) { where(company_type:) }

  def premium_cents(capital_cents)
    round_cents(capital_cents.to_d * premium_rate_per_mille / PER_MILLE)
  end

  def spouse_cents(capital_cents)
    round_cents(capital_cents.to_d * spouse_percentage / PERCENT)
  end

  def children_cents(capital_cents)
    round_cents(capital_cents.to_d * children_percentage / PERCENT)
  end

  private

  def round_cents(cents)
    cents.round(0, BigDecimal::ROUND_HALF_UP).to_i
  end
end

# == Schema Information
#
# Table name: life_insurance_policies
#
#  id                       :bigint           not null, primary key
#  capital_cents            :bigint           not null
#  children_percentage      :decimal(5, 2)    default(10.0), not null
#  company_type             :enum             not null
#  funeral_assistance_cents :bigint           default(0), not null
#  premium_rate_per_mille   :decimal(8, 4)    not null
#  spouse_percentage        :decimal(5, 2)    default(50.0), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  tenant_id                :bigint           not null
#
# Indexes
#
#  index_life_insurance_policies_on_tenant_id_and_company_type  (tenant_id,company_type) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
