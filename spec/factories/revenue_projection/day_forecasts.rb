FactoryBot.define do
  factory :revenue_projection_day_forecast, class: 'RevenueProjection::DayForecast' do
    tenant
    date { Date.new(2026, 11, 10) }
    wday { date.wday }
    day_type { 'regular' }
    typical_cents { 100_000 }
    factor { 1.0 }
    forecast_cents { 100_000 }
    low_cents { 90_000 }
    high_cents { 110_000 }
    forecast_at { date.in_time_zone.change(hour: 6) }
  end
end
