require 'rails_helper'

RSpec.describe Dashboard::TruckGroupAverages do
  let(:tenant) { create(:tenant) }
  let(:month) { Date.new(2026, 11, 1) }
  let!(:sider) { create(:truck_group, tenant:, name: 'SIDER', axles: [], plates: %w[RHJ5A50]) }
  let!(:nine_axles) { create(:truck_group, tenant:, name: '9 EIXO NACIONAL', axles: [9]) }
  let(:dashboard) { described_class.new(tenant, month) }

  def freight(plate, freight_cents, issued_at, axles: 9)
    create(:atua_transport_document, tenant:, plate:, axles:, freight_cents:, issued_at:)
  end

  before do
    create(:truck_group, tenant:, name: 'ANTIGO', axles: [], plates: %w[KLM3F45], activated_at: nil)
    create(:own_fleet, tenant:, plates: %w[RHJ5A50 AJR4391 BRA2E19 KLM3F45])
    create(:revenue_goal, :truck_group, tenant:, month:, truck_group: nine_axles, amount_cents: 16_000_000)
    create(:revenue_goal, :truck_group, tenant:, month: month.prev_month, truck_group: sider, amount_cents: 11_000_000)
    freight('AJR4391', 18_000_000, Time.zone.local(2026, 10, 10, 10))
    freight('BRA2E19', 12_000_000, Time.zone.local(2026, 10, 12, 10))
    freight('RHJ5A50', 9_000_000, Time.zone.local(2026, 10, 14, 10))
    freight('AJR4391', 4_000_000, Time.zone.local(2026, 11, 3, 10))
    freight('BRA2E19', 1_000_000, Time.zone.local(2026, 9, 3, 10))
    freight('KLM3F45', 7_000_000, Time.zone.local(2026, 11, 3, 10), axles: 6)
    create(:atua_transport_document, plate: 'AJR4391', axles: 9, freight_cents: 99_000_000, issued_at: Time.zone.local(2026, 11, 3, 10))
  end

  def averages_of(rows)
    rows.map { |row| [row.label, row.vehicles_count, *dashboard.months.map { row.average_cents(it) }, row.goal_cents] }
  end

  it 'lists the four months up to the month' do
    expect(dashboard.months).to eq([Date.new(2026, 8, 1), Date.new(2026, 9, 1), Date.new(2026, 10, 1), month])
  end

  it 'averages the billing of the trucks of each active truck group in each month and shows the goal of the month' do
    expect(averages_of(dashboard.rows)).to eq(
      [['9 EIXO NACIONAL', 2, nil, 1_000_000, 15_000_000, 2_000_000, 16_000_000], ['SIDER', 1, 0, 0, 9_000_000, 0, nil]],
    )
  end

  it 'averages the billing of every grouped truck in the total row' do
    expect(averages_of([dashboard.total_row])).to eq([['Total geral', 3, 0, 500_000, 13_000_000, 1_333_333, nil]])
  end

  it 'tells whether the average of the month reached the goal' do
    row = dashboard.rows.first

    expect(row.reached?(Date.new(2026, 10, 1))).to be(false)
    expect(described_class::Row.new(key: '1', label: 'X', vehicles_count: 1, averages: { month => 16_000_000 }, goal_cents: 16_000_000).reached?(month))
      .to be(true)
  end
end
