FactoryBot.define do
  factory :revenue_projection_snapshot, class: 'RevenueProjection::Snapshot' do
    tenant
    period_type { 'month' }
    period_start { Date.new(2026, 11, 1) }
    period_end { Date.new(2026, 11, 30) }
    taken_on { Date.new(2026, 11, 13) }
    reference_at { Time.zone.local(2026, 11, 12, 23) }
    realized_cents { 1_000_000 }
    projected_cents { 2_300_000 }
    low_cents { 2_100_000 }
    high_cents { 2_500_000 }
    days { [] }
  end
end
