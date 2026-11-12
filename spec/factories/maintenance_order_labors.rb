FactoryBot.define do
  factory :maintenance_order_labor do
    maintenance_order
    tenant { maintenance_order.tenant }
    workshop_employee { association :workshop_employee, tenant: maintenance_order.tenant }
    worked_on { Date.new(2026, 11, 11) }
    hours { 2.5 }
    activity { 'Troca das lonas de freio' }
  end
end
