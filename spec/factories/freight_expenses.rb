FactoryBot.define do
  factory :freight_expense do
    tenant
    commission_rule { association :commission_rule, tenant: }
    transport_document { association :atua_transport_document, tenant: }
    kind_type { 'commission' }
    base_cents { 100_000 }
    icms_cents { 0 }
    percentage { BigDecimal('2.0') }
    amount_cents { 2_000 }
    calculated_at { Time.current }
  end
end
