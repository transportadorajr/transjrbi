FactoryBot.define do
  factory :revenue_projection_factor, class: 'RevenueProjection::Factor' do
    tenant
    factor_type { 'weekday_holiday' }
    value { 0.3 }
    observations_count { 0 }
    learned { false }
    learned_at { Time.zone.local(2026, 11, 11, 6) }
  end
end
