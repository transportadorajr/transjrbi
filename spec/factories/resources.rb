FactoryBot.define do
  factory :resource do
    sequence(:name) { |n| "Recurso #{n}" }
    sequence(:slug) { |n| "resource_#{n}" }
    writable { true }
  end
end
