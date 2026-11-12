FactoryBot.define do
  factory :supplier do
    tenant
    sequence(:name) { |n| "AUTO PEÇAS #{n}" }
    active { true }
  end
end
