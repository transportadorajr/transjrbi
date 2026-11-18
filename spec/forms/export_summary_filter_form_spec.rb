require 'rails_helper'

RSpec.describe ExportSummaryFilterForm do
  before { travel_to Time.zone.local(2026, 11, 18, 10) }

  it 'starts on the current month without filters' do
    form = described_class.new

    expect(form.period).to eq(Date.new(2026, 11, 1)..Date.new(2026, 11, 30))
    expect(form.dashboard_filters).to eq({})
    expect(form).not_to be_filtered
  end

  it 'passes the chosen filters to the dashboard and tells it is filtered' do
    form = described_class.new(start_date: '2026-10-01', end_date: '2026-10-31', customer_group_id: '7', plant: 'plant-3', country: '')

    expect(form.dashboard_filters).to eq(customer_group_id: '7', plant: 'plant-3')
    expect(form).to be_filtered
  end

  it 'builds the period of each preset' do
    expect(described_class::PERIOD_PRESETS.index_with { |preset| described_class.preset_period(preset) }).to eq(
      week: Date.new(2026, 11, 15)..Date.new(2026, 11, 21),
      month: Date.new(2026, 11, 1)..Date.new(2026, 11, 30),
      last_month: Date.new(2026, 10, 1)..Date.new(2026, 10, 31),
      last_three_months: Date.new(2026, 9, 1)..Date.new(2026, 11, 30),
    )
  end

  it 'rejects an end date before the start date and a customer group that is not an id' do
    form = described_class.new(start_date: '2026-11-10', end_date: '2026-11-01', customer_group_id: 'abc')

    expect(form).not_to be_valid
    expect(form.errors.full_messages).to eq(['Cliente não é válido', 'Carregamentos até não pode ser anterior à data inicial'])
  end
end
