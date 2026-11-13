require 'rails_helper'

RSpec.describe RevenueProjectionHistoryFilterForm do
  before { travel_to(Time.zone.local(2026, 11, 13, 10)) }

  it 'opens the current month by default' do
    form = described_class.new

    expect(form).to be_valid
    expect(form).to have_attributes(date_range: Date.new(2026, 11, 1)..Date.new(2026, 11, 30), period_type: 'month', preset: :month)
    expect(form).not_to be_filtered
  end

  it 'recognizes each preset of the period' do
    expect(described_class::PERIOD_PRESETS.map { described_class.new(start_date: described_class.preset_period(it).first, end_date: described_class.preset_period(it).last) }
      .map { [it.preset, it.period_type] }).to eq([[:week, 'week'], [:last_week, 'week'], [:month, 'month'], [:last_month, 'month'], [:today, 'today']])
  end

  it 'opens the month or the week chosen in the select' do
    expect(described_class.new(period: 'month', start: '2026-09-01').date_range).to eq(Date.new(2026, 9, 1)..Date.new(2026, 9, 30))
    expect(described_class.new(period: 'week', start: '2026-10-04')).to have_attributes(date_range: Date.new(2026, 10, 4)..Date.new(2026, 10, 10),
                                                                                        period_type: 'week', preset: nil)
  end

  it 'treats any other range of days as a range' do
    form = described_class.new(start_date: '2026-11-02', end_date: '2026-11-11')

    expect(form).to have_attributes(period_type: 'range', preset: nil)
    expect(form).to be_filtered
    expect(form.query_params).to eq(start_date: Date.new(2026, 11, 2), end_date: Date.new(2026, 11, 11))
  end

  it 'does not accept an end date before the start date' do
    form = described_class.new(start_date: '2026-11-10', end_date: '2026-11-02')

    expect(form).not_to be_valid
    expect(form.errors[:end_date]).to eq(['não pode ser anterior à data inicial'])
  end
end
