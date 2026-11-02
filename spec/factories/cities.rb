FactoryBot.define do
  factory :city do
    tenant
    name { 'Ipatinga' }
    state { 'MG' }
    macro_region { nil }
  end
end
