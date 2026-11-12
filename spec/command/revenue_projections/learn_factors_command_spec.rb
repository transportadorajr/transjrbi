require 'rails_helper'

RSpec.describe RevenueProjections::LearnFactorsCommand do
  let(:tenant) { create(:tenant) }
  let(:at) { Time.zone.local(2026, 11, 11, 6) }

  def forecast(date, day_type, typical_cents, actual_cents)
    create(:revenue_projection_day_forecast, tenant:, date:, day_type:, typical_cents:, actual_cents:)
  end

  def factor(factor_type, wday = nil)
    tenant.revenue_projection_factors.find_by!(factor_type:, wday:)
  end

  context 'with enough days in the memory' do
    before do
      [Date.new(2026, 10, 19), Date.new(2026, 10, 26), Date.new(2026, 11, 9), Date.new(2026, 11, 16)].each { forecast(it, 'regular', 100_000, 110_000) }
      forecast(Date.new(2026, 10, 12), 'weekday_holiday', 100_000, 33_000)
      forecast(Date.new(2026, 11, 2), 'weekday_holiday', 100_000, 44_000)
      forecast(Date.new(2026, 10, 7), 'regular', 100_000, 200_000)
    end

    it 'learns the bias of each weekday and the factor of each kind of day' do
      expect(described_class.call(tenant, at:)).to eq(12)

      expect(factor('weekday_bias', 1)).to have_attributes(value: 1, observations_count: 3, learned: false, learned_at: at)
      expect(factor('weekday_bias', 3)).to have_attributes(value: 1, observations_count: 1, learned: false)
      expect(factor('weekday_holiday')).to have_attributes(value: BigDecimal('0.385'), observations_count: 2, learned: true)
      expect(factor('month_end')).to have_attributes(value: 1, observations_count: 0, learned: false)
    end

    it 'corrects the holiday factor with the weekday bias once it is learned' do
      forecast(Date.new(2026, 10, 5), 'regular', 100_000, 110_000)

      described_class.call(tenant, at:)

      expect(factor('weekday_bias', 1)).to have_attributes(value: BigDecimal('1.1'), observations_count: 4, learned: true)
      expect(factor('weekday_holiday').value).to eq(BigDecimal('0.35'))
    end

    it 'updates the factors when run again' do
      described_class.call(tenant, at:)

      expect { described_class.call(tenant, at: at + 1.day) }.not_to change(RevenueProjection::Factor, :count)
      expect(factor('weekday_holiday').learned_at).to eq(at + 1.day)
    end
  end

  it 'keeps a learned factor inside its limits' do
    [Date.new(2026, 10, 12), Date.new(2026, 11, 2)].each { forecast(it, 'weekday_holiday', 100_000, 150_000) }

    described_class.call(tenant, at:)

    expect(factor('weekday_holiday').value).to eq(1)
  end
end
