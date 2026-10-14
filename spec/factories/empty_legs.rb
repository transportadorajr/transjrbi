FactoryBot.define do
  factory :empty_leg do
    tenant
    plate { 'RHJ4E07' }
    sequence(:previous_manifest_code) { |n| 41_000 + n }
    sequence(:next_manifest_code) { |n| 42_000 + n }
    distance_km { BigDecimal('48.2') }
    precision_type { 'address' }
    status_type { 'calculated' }
    calculated_at { Time.current }
  end
end
