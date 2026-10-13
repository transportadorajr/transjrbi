FactoryBot.define do
  factory :atua_vehicle, class: 'Atua::Vehicle' do
    tenant
    sequence(:code) { |n| 800 + n }
    sequence(:plate) { |n| format('EXU%04d', n) }
    category { 'Caminhão / Cavalo' }
    ownership { 'Próprio' }
    status { 'Normal' }
    imported_at { Time.current }
  end
end
