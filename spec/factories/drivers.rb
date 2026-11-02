FactoryBot.define do
  factory :driver do
    tenant
    sequence(:code) { |n| 8_000 + n }
    display_name { 'JOSE SILVA' }
  end
end
