FactoryBot.define do
  factory :atua_expense, class: 'Atua::Expense' do
    tenant
    sequence(:code) { |n| 590_000 + n }
    posted_at { Time.zone.local(2026, 10, 1, 9, 18) }
    posted_on { Date.new(2026, 10, 1) }
    history_code { 434 }
    history_name { 'COMBUSTIVEL - DIESEL' }
    branch_code { 8042 }
    branch_name { 'JR TRANSPORTES' }
    headquarters_name { 'JR TRANSPORTES' }
    amount_cents { 725_000 }
    total_cents { 725_000 }
    raw_data { [] }
    imported_at { Time.current }
  end
end
