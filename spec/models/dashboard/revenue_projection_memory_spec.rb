require 'rails_helper'

RSpec.describe Dashboard::RevenueProjectionMemory do
  let(:tenant) { create(:tenant) }
  let(:memory) { described_class.new(tenant, today: Date.new(2026, 11, 11)) }

  def forecast(date, day_type, error_ratio)
    create(:revenue_projection_day_forecast, tenant:, date:, day_type:, actual_cents: 100_000, error_ratio:)
  end

  context 'with forecasts compared with the actual billing' do
    before do
      forecast(Date.new(2026, 11, 9), 'regular', -0.1)
      forecast(Date.new(2026, 11, 2), 'weekday_holiday', 0.5)
      forecast(Date.new(2026, 10, 26), 'regular', 0.3)
      forecast(Date.new(2026, 11, 10), 'regular', 0.05)
      forecast(Date.new(2026, 7, 1), 'regular', 0.9)
      create(:revenue_projection_day_forecast, tenant:, date: Date.new(2026, 11, 11))
      create(:revenue_projection_factor, tenant:, factor_type: 'weekday_holiday', value: 0.35, observations_count: 2, learned: true)
      create(:revenue_projection_factor, tenant:, factor_type: 'weekday_bias', wday: 0, value: 1, observations_count: 0)
      create(:revenue_projection_factor, tenant:, factor_type: 'weekday_bias', wday: 1, value: 1.1, observations_count: 8, learned: true)
    end

    it 'summarizes the daily error of the last 90 days' do
      expect(memory).to be_any
      expect(memory.mean_absolute_error).to be_within(0.0001).of(0.2375)
      expect(memory.bias).to be_within(0.0001).of(0.1875)
    end

    it 'shows where the projection misses by weekday and kind of day' do
      expect(memory.error_rows.map { [it.day_type, it.wday, it.days, it.mean_absolute_error.round(3), it.bias.round(3)] }).to eq(
        [[:regular, 1, 2, 0.2, 0.1], [:regular, 2, 1, 0.05, 0.05], [:weekday_holiday, nil, 1, 0.5, 0.5]],
      )
    end

    it 'lists what the projection learned with the weekdays from monday' do
      expect(memory.factor_rows.map { [it.factor_type, it.wday, it.value, it.observations_count, it.learned] }).to eq(
        [[:weekday_holiday, nil, 0.35, 2, true], [:weekday_bias, 1, 1.1, 8, true], [:weekday_bias, 0, 1.0, 0, false]],
      )
    end
  end

  context 'without compared forecasts' do
    it 'tells that the memory is empty' do
      expect(memory).not_to be_any
      expect(memory.mean_absolute_error).to be_nil
      expect(memory.error_rows).to be_empty
    end
  end
end
