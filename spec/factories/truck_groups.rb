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

    trait :utinga do
      name { 'Utinga' }
      axles { [] }
      plates { %w[BAV5A04 EVO8C24] }
      fuel_percentage { BigDecimal('28') }
    end

    trait :others do
      name { 'Outros' }
      axles { [] }
      remaining_axles { true }
      fuel_percentage { BigDecimal('33') }
    end
  end
end
