FactoryBot.define do
  factory :macro_region do
    tenant
    name { 'VALE DO AÇO/MG' }
    state { 'MG' }
    remaining_state { false }

    transient do
      city_names { ['Ipatinga', 'Coronel Fabriciano', 'Timóteo'] }
    end

    after(:build) do |macro_region, evaluator|
      evaluator.city_names.each do |name|
        macro_region.cities << macro_region.tenant.cities.find_or_initialize_by(name:, state: macro_region.state)
      end
    end

    trait :interior_sp do
      name { 'INTERIOR SP' }
      state { 'SP' }
      city_names { [] }
      remaining_state { true }
    end

    trait :sao_paulo do
      name { 'SAO PAULO REGIAO METROCAPITAL' }
      state { 'SP' }
      city_names { ['São Paulo', 'Santo André', 'Cubatão'] }
    end
  end
end
