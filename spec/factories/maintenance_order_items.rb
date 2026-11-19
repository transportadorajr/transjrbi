FactoryBot.define do
  factory :maintenance_order_item do
    maintenance_order
    tenant { maintenance_order.tenant }
    description { 'LONA DE FREIO' }
    total_cents { 34_000 }
    itemizable { association :maintenance_order_part, strategy: :build, maintenance_order: }
  end
end
