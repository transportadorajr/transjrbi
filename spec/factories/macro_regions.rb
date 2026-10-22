FactoryBot.define do
  factory :macro_region do
    tenant
    name { 'VALE DO AÇO/MG' }
    state { 'MG' }
    cities { ['Ipatinga', 'Coronel Fabriciano', 'Timóteo'] }
    remaining_state { false }

    trait :interior_sp do
      name { 'INTERIOR SP' }
      state { 'SP' }
      cities { [] }
      remaining_state { true }
    end

    trait :sao_paulo do
      name { 'SAO PAULO REGIAO METROCAPITAL' }
      state { 'SP' }
      cities { ['São Paulo', 'Santo André', 'Cubatão'] }
    end
  end
end
