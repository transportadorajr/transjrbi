require 'rails_helper'

RSpec.describe RevenueProjection::Calendar do
  def holiday(date, kind_type: 'holiday')
    build(:holiday, date:, kind_type:)
  end

  let(:holidays) do
    [holiday(Date.new(2026, 11, 20)), holiday(Date.new(2026, 11, 14)), holiday(Date.new(2026, 11, 15)),
     holiday(Date.new(2026, 4, 20), kind_type: 'bridge_day'), holiday(Date.new(2026, 2, 16), kind_type: 'optional')].index_by(&:date)
  end
  let(:calendar) { described_class.new(holidays) }

  describe '#day_type' do
    it 'classifies the holidays by their impact on the billing' do
      expect(calendar.day_type(Date.new(2026, 11, 20))).to eq(:weekday_holiday)
      expect(calendar.day_type(Date.new(2026, 11, 14))).to eq(:saturday_holiday)
      expect(calendar.day_type(Date.new(2026, 4, 20))).to eq(:bridge_day)
      expect(calendar.day_type(Date.new(2026, 2, 16))).to eq(:optional_day)
    end

    it 'treats a holiday on sunday as a regular day' do
      expect(calendar.day_type(Date.new(2026, 11, 15))).to eq(:regular)
    end

    it 'marks the last three days of the month out of sundays as month end' do
      expect((Date.new(2026, 11, 25)..Date.new(2026, 11, 30)).map { calendar.day_type(it) })
        .to eq(%i[regular regular month_end month_end regular month_end])
    end
  end
end
