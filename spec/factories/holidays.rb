FactoryBot.define do
  factory :holiday do
    tenant
    date { Date.new(2026, 11, 20) }
    name { 'Dia Nacional de Zumbi e da Consciência Negra' }
    scope_type { 'national' }
    kind_type { 'holiday' }
  end
end
