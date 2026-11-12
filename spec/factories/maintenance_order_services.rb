FactoryBot.define do
  factory :maintenance_order_service do
    maintenance_order
    tenant { maintenance_order.tenant }
    supplier { association :supplier, tenant: maintenance_order.tenant }
    description { 'Retífica do tambor de freio' }
    quoted_cents { 45_000 }
  end
end
