FactoryBot.define do
  factory :life_insurance_policy do
    tenant
    company_type { 'transjr' }
    capital_cents { 11_500_000 }
    premium_rate_per_mille { BigDecimal('0.3185') }
    spouse_percentage { 50 }
    children_percentage { 10 }
    funeral_assistance_cents { 600_000 }
  end
end
