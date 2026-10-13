FactoryBot.define do
  factory :atua_transport_document, class: 'Atua::TransportDocument' do
    tenant
    sequence(:code) { |n| 80_000 + n }
    sequence(:number) { |n| (74_000 + n).to_s }
    series { 1 }
    document_kind { 'cte' }
    issue_kind { 'Normal' }
    cte_status { 'Autorizado' }
    issued_at { Time.zone.local(2026, 10, 1, 16, 45) }
    posted_on { Date.new(2026, 10, 1) }
    branch_name { 'JR TRANSPORTES' }
    freight_cents { 55_504 }
    weight_tons { BigDecimal('1.917') }
    weight_kg { BigDecimal('1917') }
    imported_at { Time.current }
  end
end
