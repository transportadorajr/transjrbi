FactoryBot.define do
  factory :revenue_goal do
    tenant
    month { Date.current.beginning_of_month }
    target_type { 'company' }
    amount_cents { 100_000_000 }

    trait :vehicle do
      target_type { 'vehicle' }
      plate { 'AJR4391' }
    end

    trait :customer_group do
      target_type { 'customer_group' }
      customer_group { association :customer_group, tenant: }
    end
  end
end
