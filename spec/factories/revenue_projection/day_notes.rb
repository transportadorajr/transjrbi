FactoryBot.define do
  factory :revenue_projection_day_note, class: 'RevenueProjection::DayNote' do
    tenant
    user { association :user, tenant: }
    date { Date.new(2026, 11, 2) }
    body { 'Greve no porto' }
  end
end
