require 'rails_helper'

RSpec.describe RevenueGoal::BusinessCalendar do
  let(:holidays) do
    { Date.new(2026, 11, 2) => build(:holiday, date: Date.new(2026, 11, 2)),
      Date.new(2026, 11, 20) => build(:holiday, date: Date.new(2026, 11, 20), kind_type: 'optional') }
  end

  it 'counts Monday to Saturday without the holidays and keeps the optional days' do
    calendar = described_class.new(holidays)

    expect(calendar.business_day?(Date.new(2026, 11, 1))).to be(false)
    expect(calendar.business_day?(Date.new(2026, 11, 2))).to be(false)
    expect(calendar.business_day?(Date.new(2026, 11, 7))).to be(true)
    expect(calendar.business_day?(Date.new(2026, 11, 20))).to be(true)
    expect(calendar.business_days(Date.new(2026, 11, 1)..Date.new(2026, 11, 8))).to eq((Date.new(2026, 11, 3)..Date.new(2026, 11, 7)).to_a)
  end
end
