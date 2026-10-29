FactoryBot.define do
  factory :excluded_issuer do
    tenant
    sequence(:code) { |n| 6_000 + n }
    name { 'MAYCON DORALINO SANTOS LORENA' }
  end
end
