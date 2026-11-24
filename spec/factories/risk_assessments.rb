FactoryBot.define do
  factory :risk_assessment do
    employee
    tenant { employee.tenant }
    provider_type { 'apisul' }
    score { 160 }
    valid_until { Date.new(2027, 5, 11) }
  end
end
