FactoryBot.define do
  factory :export_plant do
    tenant
    customer_group { association :customer_group, tenant: }
    sequence(:name) { |n| "PLANTA #{n}" }
    cities { ['IPATINGA'] }
    activated_at { Time.current }
  end
end
