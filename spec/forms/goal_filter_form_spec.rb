require 'rails_helper'

RSpec.describe GoalFilterForm do
  before { travel_to(Time.zone.local(2026, 11, 13, 10)) }

  it 'defaults to the current month' do
    form = described_class.new

    expect(form).to be_valid
    expect(form.month_value).to eq(Date.new(2026, 11, 1))
    expect(form).to be_current_month
  end

  it 'reads the chosen month' do
    form = described_class.new(month: '2026-09')

    expect(form.month_value).to eq(Date.new(2026, 9, 1))
    expect(form).not_to be_current_month
  end

  it 'rejects an invalid month' do
    expect(described_class.new(month: 'setembro')).not_to be_valid
  end
end
