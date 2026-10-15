FactoryBot.define do
  factory :customer_group do
    tenant
    sequence(:name) { |n| "GRUPO #{n}" }
    terms { [] }
    activated_at { Time.current }
  end
end
