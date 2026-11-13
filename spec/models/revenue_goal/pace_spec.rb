require 'rails_helper'

RSpec.describe RevenueGoal::Pace do
  let(:month) { Date.new(2026, 11, 1) }
  let(:holidays) { { Date.new(2026, 11, 2) => build(:holiday, date: Date.new(2026, 11, 2)) } }

  def pace(reference_date, projection: nil)
    described_class.new(month, reference_date:, holidays:, projection:)
  end

  def projection(realized_cents:, projected_cents:, history_days: 20)
    instance_double(RevenueProjection::Result, realized_cents:, projected_cents:, history?: history_days.positive?)
  end

  describe '#business_days' do
    it 'counts Monday to Saturday without the holidays' do
      expect(pace(Date.new(2026, 11, 10)).business_days.size).to eq(24)
    end

    it 'keeps the optional days as business days' do
      holidays[Date.new(2026, 11, 20)] = build(:holiday, date: Date.new(2026, 11, 20), kind_type: 'optional')

      expect(pace(Date.new(2026, 11, 10)).business_days).to include(Date.new(2026, 11, 20))
    end
  end

  describe '#project' do
    it 'follows the learned projection while the month is open' do
      current = pace(Date.new(2026, 11, 10), projection: projection(realized_cents: 1_000_000, projected_cents: 2_500_000))

      expect(current).to be_learned
      expect(current.project(200_000)).to eq(500_000)
    end

    it 'falls back to the elapsed business days without a learned projection' do
      current = pace(Date.new(2026, 11, 10), projection: projection(realized_cents: 1_000_000, projected_cents: 1_000_000, history_days: 0))

      expect(current).not_to be_learned
      expect(current.elapsed_business_days).to eq(7)
      expect(current.remaining_business_days).to eq(17)
      expect(current.project(700_000)).to eq(2_400_000)
    end

    it 'keeps the realized billing once the month is closed' do
      expect(pace(Date.new(2026, 12, 3)).project(700_000)).to eq(700_000)
    end

    it 'has no projection before the month starts' do
      expect(pace(Date.new(2026, 10, 30)).project(0)).to be_nil
    end
  end
end
