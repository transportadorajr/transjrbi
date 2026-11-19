FactoryBot.define do
  factory :maintenance_order_mechanic do
    maintenance_order
    tenant { maintenance_order.tenant }
    workshop_employee { association :workshop_employee, tenant: maintenance_order.tenant }
  end
end
