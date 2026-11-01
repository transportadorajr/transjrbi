FactoryBot.define do
  factory :excluded_driver do
    tenant
    sequence(:code) { |n| 7_000 + n }
    name { 'JOSE DA SILVA' }
  end
end
