require 'rails_helper'

RSpec.describe RevenueProjection::Baseline do
  let(:daily_totals) do
    {
      Date.new(2026, 10, 19) => 1_000, Date.new(2026, 10, 26) => 3_000, Date.new(2026, 11, 2) => 2_000,
      Date.new(2026, 11, 9) => 6_000, Date.new(2026, 11, 7) => 500
    }
  end
  let(:hourly_totals) do
    {
      Time.zone.local(2026, 11, 9, 8) => 1_000,
      Time.zone.local(2026, 11, 9, 14) => 3_000,
      Time.zone.local(2026, 11, 2, 8) => 1_000,
      Time.zone.local(2026, 11, 2, 14) => 3_000,
    }
  end
  let(:baseline) { described_class.new(daily_totals, hourly_totals) }

  describe '#typical' do
    it 'takes the median of the days of the same weekday' do
      expect(baseline.typical(1)).to eq(2_500.0)
      expect(baseline.typical(6)).to eq(500.0)
    end

    it 'interpolates the lower and the upper quartiles' do
      expect(baseline.typical(1, described_class::LOW)).to eq(1_750.0)
      expect(baseline.typical(1, described_class::HIGH)).to eq(3_750.0)
    end

    it 'is zero for a weekday without history' do
      expect(baseline.typical(0)).to eq(0.0)
    end
  end

  describe '#share_until' do
    it 'accumulates the share of the day billed until the given time' do
      expect(baseline.share_until(1, 8.0)).to eq(0.0)
      expect(baseline.share_until(1, 8.5)).to eq(0.125)
      expect(baseline.share_until(1, 12.0)).to eq(0.25)
      expect(baseline.share_until(1, 23.5)).to eq(1.0)
    end

    it 'spreads the day evenly for a weekday without hourly history' do
      expect(baseline.share_until(3, 6.0)).to eq(0.25)
    end
  end

  describe '#days_count' do
    it 'counts the days of the history' do
      expect(baseline.days_count).to eq(5)
    end
  end
end
