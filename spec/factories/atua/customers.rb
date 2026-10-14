FactoryBot.define do
  factory :atua_customer, class: 'Atua::Customer' do
    tenant
    sequence(:code) { |n| 7000 + n }
    name { 'ARCELORMITTAL BRASIL S.A.' }
    document { '17.469.701/0066-12' }
    document_digits { '17469701006612' }
    person_kind { 'Pessoa Jurídica' }
    city { 'JOAO MONLEVADE' }
    state { 'MG' }
    status { 'Normal' }
    imported_at { Time.current }
  end
end
