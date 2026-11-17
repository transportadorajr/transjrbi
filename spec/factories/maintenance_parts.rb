FactoryBot.define do
  factory :maintenance_part do
    tenant
    sequence(:description) { |n| "PEÇA #{n}" }
    unit { 'UN' }
    unit_price_cents { 0 }
    active { true }
  end
end
