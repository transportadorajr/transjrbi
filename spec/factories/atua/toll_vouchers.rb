FactoryBot.define do
  factory :atua_toll_voucher, class: 'Atua::TollVoucher' do
    tenant
    sequence(:code) { |n| "2:#{74_000 + n}:#{n}" }
    sequence(:transport_document_number) { |n| (74_000 + n).to_s }
    sequence(:order_number) { |n| "1000000000000000#{n}" }
    issued_on { Date.new(2026, 10, 24) }
    branch_code { 8042 }
    branch_name { 'JR TRANSPORTES' }
    issuer_name { 'TAG TESTE' }
    toll_cents { 58_517 }
    charged_toll_cents { 0 }
    total_cents { 58_517 }
    raw_data { {} }
    imported_at { Time.current }
  end
end
