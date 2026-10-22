FactoryBot.define do
  factory :truck_group do
    tenant
    name { 'Rodotrem' }
    axles { [9] }
    fuel_percentage { BigDecimal('35') }
    activated_at { Time.current }

    trait :ls do
      name { 'LS' }
      axles { [6] }
      fuel_percentage { BigDecimal('30') }
    end
  end
end
