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

    after(:create) do |part|
      create(:maintenance_order_item, itemizable: part, maintenance_order: part.maintenance_order, description: part.description,
                                      notes: part.notes, total_cents: part.total_cents)
    end
  end
end
