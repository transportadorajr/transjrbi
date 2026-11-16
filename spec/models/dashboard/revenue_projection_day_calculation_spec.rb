require 'rails_helper'

RSpec.describe Dashboard::RevenueProjectionDayCalculation do
  let(:tenant) { create(:tenant) }
  let(:date) { Date.new(2026, 11, 3) }

  it 'has nothing to show without the forecast of the day' do
    calculation = described_class.new(tenant, date)

    expect(calculation).not_to be_any
    expect(calculation.forecast_cents).to be_nil
  end

  context 'with the forecast of the day and the billing of the previous weeks' do
    before do
      create(:revenue_projection_day_forecast, tenant:, date:, typical_cents: 150_000, factor: 0.95, forecast_cents: 142_500, low_cents: 120_000,
                                               high_cents: 160_000, day_type: 'regular')
      create(:revenue_projection_daily_total, tenant:, date: Date.new(2026, 10, 27), billed_cents: 150_000)
      create(:revenue_projection_daily_total, tenant:, date: Date.new(2026, 10, 20), billed_cents: 140_000)
      create(:revenue_projection_daily_total, tenant:, date: Date.new(2026, 10, 13), billed_cents: 30_000)
      create(:holiday, tenant:, date: Date.new(2026, 10, 13))
      create(:revenue_projection_daily_total, tenant:, date: Date.new(2026, 10, 26), billed_cents: 90_000)
      create(:revenue_projection_daily_total, tenant:, date: Date.new(2026, 8, 4), billed_cents: 80_000)
      create(:revenue_projection_daily_total, tenant:, date:, billed_cents: 200_000)
      create(:revenue_projection_daily_total, tenant: create(:tenant), date: Date.new(2026, 10, 6), billed_cents: 9_900_000)
    end

    it 'shows the base of the forecast and the regular days of the same weekday in the last twelve weeks' do
      calculation = described_class.new(tenant, date)

      expect(calculation).to be_any
      expect(calculation).to have_attributes(day_type: 'regular', typical_cents: 150_000, factor: 0.95, forecast_cents: 142_500, low_cents: 120_000,
                                             high_cents: 160_000)
      expect(calculation.window).to eq(Date.new(2026, 8, 11)...date)
      expect(calculation.history_days.map { [it.date, it.billed_cents] }).to eq([[Date.new(2026, 10, 20), 140_000], [Date.new(2026, 10, 27), 150_000]])
    end
  end
end
