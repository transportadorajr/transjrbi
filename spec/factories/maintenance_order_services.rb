FactoryBot.define do
  factory :maintenance_order_service do
    maintenance_order
    tenant { maintenance_order.tenant }
    supplier { association :supplier, tenant: maintenance_order.tenant }
    description { 'Retífica do tambor de freio' }
    quoted_cents { 45_000 }

    after(:create) do |service|
      create(:maintenance_order_item, itemizable: service, maintenance_order: service.maintenance_order, description: service.description,
                                      notes: service.notes, total_cents: service.value_cents)
    end
  end
end
