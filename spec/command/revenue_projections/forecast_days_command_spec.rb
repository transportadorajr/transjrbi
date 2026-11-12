require 'rails_helper'

RSpec.describe RevenueProjections::ForecastDaysCommand do
  let(:tenant) { create(:tenant) }

  before do
    [Date.new(2026, 10, 19), Date.new(2026, 10, 26), Date.new(2026, 11, 2)].each_with_index do |date, index|
      create(:revenue_projection_daily_total, tenant:, date:, billed_cents: (index + 1) * 100_000)
    end
    create(:revenue_projection_factor, tenant:, factor_type: 'weekday_bias', wday: 1, value: 1.1, learned: true)
  end

  it 'stores the forecast of each day from the memory before it' do
    travel_to(Time.zone.local(2026, 11, 9, 6)) do
      expect(described_class.call(tenant, Date.new(2026, 11, 9)..Date.new(2026, 11, 10))).to eq(1)
    end

    expect(tenant.revenue_projection_day_forecasts.sole).to have_attributes(
      date: Date.new(2026, 11, 9), wday: 1, day_type: 'regular', typical_cents: 200_000, factor: BigDecimal('1.1'), forecast_cents: 220_000,
      low_cents: 165_000, high_cents: 275_000, actual_cents: nil, backfilled: false, forecast_at: Time.zone.local(2026, 11, 9, 6)
    )
  end

  it 'keeps the first forecast of a day' do
    described_class.call(tenant, Date.new(2026, 11, 9)..Date.new(2026, 11, 9))
    create(:revenue_projection_daily_total, tenant:, date: Date.new(2026, 10, 12), billed_cents: 900_000)

    expect { described_class.call(tenant, Date.new(2026, 11, 9)..Date.new(2026, 11, 9)) }.not_to change(RevenueProjection::DayForecast, :count)

    expect(tenant.revenue_projection_day_forecasts.sole.typical_cents).to eq(200_000)
  end

  it 'reads the factors learned after the tenant was loaded' do
    described_class.call(tenant, Date.new(2026, 11, 9)..Date.new(2026, 11, 9))
    RevenueProjection::Factor.where(tenant:).update_all(value: 1.2)

    described_class.call(tenant, Date.new(2026, 11, 16)..Date.new(2026, 11, 16))

    expect(tenant.revenue_projection_day_forecasts.find_by!(date: Date.new(2026, 11, 16)).factor).to eq(BigDecimal('1.2'))
  end

  it 'marks the forecasts rebuilt from the history' do
    described_class.call(tenant, Date.new(2026, 11, 9)..Date.new(2026, 11, 9), backfilled: true)

    expect(tenant.revenue_projection_day_forecasts.sole).to be_backfilled
  end
end
