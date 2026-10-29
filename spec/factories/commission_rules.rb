FactoryBot.define do
  factory :commission_rule do
    tenant
    customer_group { association :customer_group, tenant: }
    name { 'Nacional' }
    destination_type { 'national' }
    base_type { 'freight_without_icms' }
    percentage { BigDecimal('2.0') }
    cities { [] }
    activated_at { Time.current }

    trait :argentina do
      name { 'Argentina' }
      destination_type { 'foreign' }
      base_type { 'freight' }
      percentage { BigDecimal('1.3') }
      cities { ['Buenos Aires', 'Puerto Iguazú', 'Rosario'] }
      recipient_terms { %w[FERROSIDER ACINDAR SIAT TERNIUM] }
    end

    trait :paraguay do
      name { 'Paraguai' }
      destination_type { 'foreign' }
      base_type { 'freight' }
      percentage { BigDecimal('1.5') }
      cities { ['Asunción', 'Ciudad del Este'] }
      recipient_terms { %w[LACERIE GALLO ACEROS FERROPAR CJX ELIN FATA WADRA MERCOFER MONICA PERFILADOS] }
    end
  end
end
