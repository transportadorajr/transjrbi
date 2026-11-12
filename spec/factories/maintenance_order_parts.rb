FactoryBot.define do
  factory :maintenance_order_part do
    maintenance_order
    tenant { maintenance_order.tenant }
    description { 'LONA DE FREIO' }
    quantity { 4 }
    unit { 'UN' }
    source_type { 'stock' }
    unit_price_cents { 8_500 }
    total_cents { 34_000 }
  end
end
