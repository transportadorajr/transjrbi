FactoryBot.define do
  factory :tonnage_rate do
    tenant
    customer_group { association :customer_group, tenant: }
    name { 'Brasiltec' }
    nickname { 'Cubatão' }
    origin_city { 'Cubatão' }
    origin_state { 'SP' }
    valid_month { Date.new(2026, 10, 1) }
    rate_cents { 1_257 }
    activated_at { Time.current }
  end
end
