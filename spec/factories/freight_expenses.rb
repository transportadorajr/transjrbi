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

    trait :tonnage do
      commission_rule { nil }
      tonnage_rate { association :tonnage_rate, tenant: }
      kind_type { 'tonnage' }
      base_cents { nil }
      percentage { nil }
      weight_tons { BigDecimal('32.5') }
      rate_cents { 1_257 }
      amount_cents { 40_853 }
    end

    trait :insurance do
      commission_rule { nil }
      insurance_rate { InsuranceRate.find_by(tenant:) || association(:insurance_rate, tenant:) }
      kind_type { 'insurance' }
      base_cents { 1_000_000 }
      percentage { BigDecimal('0.022') }
      iof_percentage { BigDecimal('0') }
      iof_cents { 0 }
      amount_cents { 220 }
    end

    trait :tarp_lining do
      commission_rule { nil }
      kind_type { 'tarp_lining' }
      base_cents { nil }
      percentage { nil }
      rate_cents { 5_500 }
      amount_cents { 5_500 }
    end

    trait :fuel do
      commission_rule { nil }
      truck_group { tenant.truck_groups.first || association(:truck_group, tenant:) }
      kind_type { 'fuel' }
      base_cents { 1_000_000 }
      percentage { BigDecimal('35') }
      amount_cents { 350_000 }
    end
  end
end
