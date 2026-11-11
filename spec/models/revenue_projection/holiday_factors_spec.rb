require 'rails_helper'

RSpec.describe RevenueProjection::HolidayFactors do
  def holiday(date, kind_type: 'holiday')
    build(:holiday, date:, kind_type:)
  end

  def mondays(from, count, cents)
    Array.new(count) { |week| [from + (week * 7), cents] }.to_h
  end

  describe '.category' do
    it 'groups the holidays by the impact they have on the billing' do
      expect(described_class.category(holiday(Date.new(2026, 11, 20)))).to eq(:weekday)
      expect(described_class.category(holiday(Date.new(2026, 11, 14)))).to eq(:saturday)
      expect(described_class.category(holiday(Date.new(2026, 4, 20), kind_type: 'bridge_day'))).to eq(:bridge_day)
      expect(described_class.category(holiday(Date.new(2026, 2, 16), kind_type: 'optional'))).to eq(:optional)
      expect(described_class.category(holiday(Date.new(2026, 11, 15)))).to be_nil
      expect(described_class.category(nil)).to be_nil
    end
  end

  describe '#factors' do
    it 'uses the default factors without enough holidays in the history' do
      factors = described_class.new({}, {})

      expect(factors.factors).to eq(weekday: 0.30, saturday: 0.80, bridge_day: 0.60, optional: 0.50)
    end

    it 'learns the factor from the holidays billed in the history' do
      aparecida = Date.new(2026, 10, 12)
      all_souls = Date.new(2026, 11, 2)
      daily_totals = mondays(Date.new(2026, 9, 7), 12, 10_000).merge(aparecida => 4_000, all_souls => 5_000)
      holidays = { aparecida => holiday(aparecida), all_souls => holiday(all_souls) }

      factors = described_class.new(holidays, daily_totals)

      expect(factors.factors).to eq(weekday: 0.45, saturday: 0.80, bridge_day: 0.60, optional: 0.50)
    end

    it 'keeps the default factor with a single holiday in the history' do
      aparecida = Date.new(2026, 10, 12)
      daily_totals = mondays(Date.new(2026, 9, 7), 12, 10_000).merge(aparecida => 4_000)

      factors = described_class.new({ aparecida => holiday(aparecida) }, daily_totals)

      expect(factors.factors.fetch(:weekday)).to eq(0.30)
    end
  end

  describe '#factor' do
    let(:black_consciousness) { Date.new(2026, 11, 20) }
    let(:factors) { described_class.new({ black_consciousness => holiday(black_consciousness) }, {}) }

    it 'reduces a holiday and keeps a normal day' do
      expect(factors.factor(black_consciousness)).to eq(0.30)
      expect(factors.factor(Date.new(2026, 11, 19))).to eq(1.0)
    end
  end
end
