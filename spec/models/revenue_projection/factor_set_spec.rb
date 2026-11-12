require 'rails_helper'

RSpec.describe RevenueProjection::FactorSet do
  let(:factors) do
    described_class.new([build(:revenue_projection_factor, factor_type: 'weekday_holiday', value: 0.4),
                         build(:revenue_projection_factor, factor_type: 'weekday_bias', wday: 1, value: 1.1)])
  end

  it 'reads the stored factors and falls back to the defaults' do
    expect(factors.value(:weekday_holiday)).to eq(0.4)
    expect(factors.value(:saturday_holiday)).to eq(0.8)
    expect(factors.bias(1)).to eq(1.1)
    expect(factors.bias(2)).to eq(1.0)
  end

  it 'combines the factor of the day with the bias of the weekday' do
    expect(factors.day_factor(:weekday_holiday, 1)).to be_within(0.0001).of(0.44)
    expect(factors.day_factor(:regular, 1)).to eq(1.1)
    expect(factors.day_factor(:month_end, 2)).to eq(1.0)
  end

  it 'lists the factors of the days' do
    expect(factors.to_h).to eq(weekday_holiday: 0.4, saturday_holiday: 0.8, bridge_day: 0.6, optional_day: 0.5, month_end: 1.0)
  end
end
