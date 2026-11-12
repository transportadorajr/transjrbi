require 'rails_helper'

RSpec.describe RevenueProjection::Forecaster do
  let(:tenant) { create(:tenant) }
  let(:hourly) do
    Array.new(24, 0).tap do
      it[8] = 25_000
      it[14] = 75_000
    end
  end
  let(:daily_totals) do
    [[Date.new(2026, 10, 19), 100_000], [Date.new(2026, 10, 26), 300_000], [Date.new(2026, 11, 2), 200_000], [Date.new(2026, 11, 9), 600_000]]
      .to_h { |date, billed_cents| [date, build(:revenue_projection_daily_total, tenant:, date:, billed_cents:, hourly_cents: hourly)] }
  end
  let(:holidays) { {} }
  let(:factors) { RevenueProjection::FactorSet.new([build(:revenue_projection_factor, factor_type: 'weekday_bias', wday: 1, value: 1.1)]) }
  let(:forecaster) { described_class.new(daily_totals, RevenueProjection::Calendar.new(holidays), factors) }

  describe '#forecast' do
    it 'forecasts a day from the median of the same weekday corrected by the bias' do
      forecast = forecaster.forecast(Date.new(2026, 11, 16))

      expect(forecast).to have_attributes(day_type: :regular, typical_cents: 250_000, factor: 1.1, forecast_cents: 275_000,
                                          low_cents: 192_500, high_cents: 412_500)
    end

    it 'uses only the days before the reference date' do
      expect(forecaster.forecast(Date.new(2026, 11, 16), as_of: Date.new(2026, 11, 3))).to have_attributes(typical_cents: 200_000)
    end

    it 'does not forecast a weekday without history' do
      expect(forecaster.forecast(Date.new(2026, 11, 17))).to be_nil
    end

    context 'with holidays in the history' do
      let(:holidays) { { Date.new(2026, 11, 2) => build(:holiday, date: Date.new(2026, 11, 2)) } }

      it 'leaves the holidays out of the typical billing' do
        expect(forecaster.forecast(Date.new(2026, 11, 16))).to have_attributes(typical_cents: 300_000)
      end
    end
  end

  describe '#share_until' do
    it 'accumulates the share of the day usually billed until the given time' do
      expect(forecaster.share_until(1, 8.5, as_of: Date.new(2026, 11, 16))).to eq(0.125)
      expect(forecaster.share_until(1, 12.0, as_of: Date.new(2026, 11, 16))).to eq(0.25)
    end

    it 'spreads the day evenly without hourly history' do
      expect(forecaster.share_until(3, 6.0, as_of: Date.new(2026, 11, 16))).to eq(0.25)
    end
  end

  describe '#history_days' do
    it 'counts the regular days of the window' do
      expect(forecaster.history_days(Date.new(2026, 11, 16))).to eq(4)
    end
  end
end
