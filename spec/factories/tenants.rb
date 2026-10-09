FactoryBot.define do
  factory :tenant do
    name { 'Transportadora JR Ltda' }
    trade_name { 'TransJR' }
    sequence(:legal_id) { |n| format('12.345.678/%04d-90', n) }
  end
end
