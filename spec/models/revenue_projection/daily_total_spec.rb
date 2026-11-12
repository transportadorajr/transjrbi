require 'rails_helper'

RSpec.describe RevenueProjection::DailyTotal do
  let(:tenant) { create(:tenant) }

  it 'stores a single total per day and validates the day type' do
    create(:revenue_projection_daily_total, tenant:)

    total = build(:revenue_projection_daily_total, tenant:, day_type: 'carnival')

    expect(total).not_to be_valid
    expect(total.errors.attribute_names).to contain_exactly(:date, :day_type)
  end
end
