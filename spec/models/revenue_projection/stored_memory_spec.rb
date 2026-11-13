require 'rails_helper'

RSpec.describe RevenueProjection::StoredMemory do
  let(:tenant) { create(:tenant) }
  let(:memory) { described_class.new(tenant) }

  def snapshot(period_type, period, taken_on, tenant: self.tenant)
    create(:revenue_projection_snapshot, tenant:, period_type:, period_start: period.first, period_end: period.last, taken_on:)
  end

  before do
    snapshot('month', Date.new(2026, 11, 1).all_month, Date.new(2026, 11, 2))
    snapshot('month', Date.new(2026, 11, 1).all_month, Date.new(2026, 11, 1))
    snapshot('week', Date.new(2026, 11, 1)..Date.new(2026, 11, 7), Date.new(2026, 11, 1))
    snapshot('week', Date.new(2026, 10, 25)..Date.new(2026, 10, 31), Date.new(2026, 10, 25))
    snapshot('month', Date.new(2026, 11, 1).all_month, Date.new(2026, 11, 3), tenant: create(:tenant))
    create(:revenue_projection_daily_total, tenant:, date: Date.new(2026, 11, 2), billed_cents: 40_000)
    create(:revenue_projection_day_forecast, tenant:, date: Date.new(2026, 11, 3), forecast_cents: 30_000)
  end

  it 'reads the snapshots, the daily totals and the forecasts stored for the tenant' do
    expect(memory.snapshots_of('month', Date.new(2026, 11, 1)).map(&:taken_on)).to eq([Date.new(2026, 11, 1), Date.new(2026, 11, 2)])
    expect(memory.snapshots_taken('month', Date.new(2026, 11, 2)..Date.new(2026, 11, 5)).map(&:taken_on)).to eq([Date.new(2026, 11, 2)])
    expect(memory.week_snapshots_within(Date.new(2026, 11, 1).all_month).map(&:period_start)).to eq([Date.new(2026, 11, 1)])
    expect(memory.totals(Date.new(2026, 11, 1).all_month).transform_values(&:billed_cents)).to eq(Date.new(2026, 11, 2) => 40_000)
    expect(memory.forecasts(Date.new(2026, 11, 1)..Date.new(2026, 11, 2))).to eq({})
    expect(memory).not_to be_recalculated
  end
end
