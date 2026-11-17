FactoryBot.define do
  factory :maintenance_service do
    tenant
    sequence(:description) { |n| "SERVIÇO #{n}" }
    price_cents { 0 }
    active { true }
  end
end
