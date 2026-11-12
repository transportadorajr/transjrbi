FactoryBot.define do
  factory :revenue_projection_daily_total, class: 'RevenueProjection::DailyTotal' do
    tenant
    date { Date.new(2026, 11, 10) }
    wday { date.wday }
    day_type { 'regular' }
    billed_cents { 100_000 }
    documents_count { 1 }
    hourly_cents { [] }
    consolidated_at { Time.zone.local(2026, 11, 11, 6) }
  end
end
