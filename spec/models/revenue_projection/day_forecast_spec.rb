require 'rails_helper'

RSpec.describe RevenueProjection::DayForecast do
  let(:tenant) { create(:tenant) }

  it 'stores a single forecast per day and lists only the compared ones' do
    create(:revenue_projection_day_forecast, tenant:)
    compared = create(:revenue_projection_day_forecast, tenant:, date: Date.new(2026, 11, 9), actual_cents: 120_000)

    expect(build(:revenue_projection_day_forecast, tenant:)).not_to be_valid
    expect(described_class.with_actual).to eq([compared])
  end
end
