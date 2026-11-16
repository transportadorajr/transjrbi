require 'rails_helper'

RSpec.describe Dashboard::Goals do
  let(:tenant) { create(:tenant) }
  let(:month) { Date.new(2026, 11, 1) }
  let(:own_fleet) { create(:own_fleet, tenant:, plates: %w[AJR4391 RHJ5A50 QWE1A23]) }
  let(:pace) { RevenueGoal::Pace.new(month, reference_date: Date.new(2026, 11, 10), holidays: {}) }

  def freight(plate, freight_cents, issued_at: Time.zone.local(2026, 11, 5, 10), **)
    create(:atua_transport_document, tenant:, plate:, freight_cents:, issued_at:, **)
  end

  def dashboard
    described_class.new(tenant.billable_freights, goals: tenant.revenue_goals.for_month(month).to_a, pace:, own_fleet:)
  end

  before do
    create(:revenue_goal, tenant:, month:, amount_cents: 10_000_000)
    create(:revenue_goal, :vehicle, tenant:, month:, plate: 'AJR4391', amount_cents: 1_000_000)
    create(:revenue_goal, :vehicle, tenant:, month:, plate: 'RHJ5A50', amount_cents: 2_000_000)
    freight('AJR4391', 600_000)
    freight('AJR4391', 300_000, issued_at: Time.zone.local(2026, 11, 9, 8))
    freight('RHJ5A50', 400_000)
    freight('XYZ9K87', 250_000)
    freight('AJR4391', 999_999, issued_at: Time.zone.local(2026, 10, 31, 23))
    freight('AJR4391', 888_888, canceled_at: Time.zone.local(2026, 11, 6))
  end

  it 'compares the company billing of the month with its goal' do
    company = dashboard.company

    expect(company.goal_cents).to eq(10_000_000)
    expect(company.realized_cents).to eq(1_550_000)
    expect(company.missing_cents).to eq(8_450_000)
    expect(company.ratio).to eq(BigDecimal('0.155'))
    expect(company.projected_cents).to eq(4_843_750)
    expect(company.status).to eq(:behind)
    expect(dashboard.required_daily_cents).to eq(497_059)
  end

  it 'ranks the own fleet by billing with the third party plates apart' do
    rows = dashboard.sorted_vehicle_rows(nil, nil)

    expect(rows.map { [it.key, it.goal_cents, it.realized_cents, it.missing_cents, it.status] }).to eq(
      [
        ['AJR4391', 1_000_000, 900_000, 100_000, :on_track],
        ['RHJ5A50', 2_000_000, 400_000, 1_600_000, :behind],
        ['QWE1A23', nil, 0, nil, nil],
      ],
    )
    expect(dashboard.third_party_row.realized_cents).to eq(250_000)
    expect(dashboard.vehicle_goals_cents).to eq(3_000_000)
  end

  it 'sorts the ranking by the goal achievement' do
    expect(dashboard.sorted_vehicle_rows('ratio', 'desc').map(&:key)).to eq(%w[AJR4391 RHJ5A50 QWE1A23])
    expect(dashboard.sorted_vehicle_rows('label', 'asc').map(&:key)).to eq(%w[AJR4391 QWE1A23 RHJ5A50])
  end

  it 'classifies a projection between 90% and 100% of the goal as attention' do
    row = described_class::Row.new(key: 'company', label: 'Transportadora', goal_cents: 1_000, realized_cents: 500, projected_cents: 950)

    expect(row.status).to eq(:attention)
  end

  context 'with the customer groups and the week' do
    let(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
    let(:arcelor) { create(:customer_group, tenant:, name: 'ARCELOR') }
    let(:week) { RevenueGoal::Week.new(Date.new(2026, 11, 10), goals: tenant.revenue_goals.to_a, holidays: {}) }

    def dashboard_with_customers
      described_class.new(tenant.billable_freights, goals: tenant.revenue_goals.for_month(month).to_a, pace:, own_fleet:, week:,
                                                    customer_groups: [arcelor, usiminas])
    end

    before do
      create(:revenue_goal, :customer_group, tenant:, month:, customer_group: usiminas, amount_cents: 5_000_000)
      freight('AJR4391', 700_000, taker_code: create(:atua_customer, tenant:, customer_group: usiminas).code)
      freight('RHJ5A50', 100_000, issued_at: Time.zone.local(2026, 11, 9, 9), taker_code: create(:atua_customer, tenant:, customer_group: arcelor).code)
    end

    it 'compares the billing of each customer group with its goal in the month and in the week' do
      rows = dashboard_with_customers.sorted_customer_rows

      expect(rows.map { [it.label, it.goal_cents, it.realized_cents, it.week_goal_cents, it.week_realized_cents, it.cut] }).to eq(
        [
          ['USIMINAS', 5_000_000, 700_000, 1_200_000, 0, { customer_group_id: usiminas.id }],
          ['ARCELOR', nil, 100_000, nil, 100_000, { customer_group_id: arcelor.id }],
        ],
      )
      expect(rows.first.week_ratio).to eq(0)
      expect(dashboard_with_customers.ungrouped_row).to have_attributes(realized_cents: 1_550_000, week_realized_cents: 300_000, cut: nil)
    end

    it 'sums the company billing of the week against the week goal' do
      company = dashboard_with_customers.company

      expect(company.week_goal_cents).to eq(2_400_000)
      expect(company.week_realized_cents).to eq(400_000)
      expect(company.week_missing_cents).to eq(2_000_000)
    end
  end

  it 'accumulates the billing and the goal day by day for the chart' do
    realized, expected = dashboard.chart_data

    expect(realized[:data].keys).to eq((1..10).map { format('%02d/11', it) })
    expect(realized[:data]['04/11']).to eq(0.0)
    expect(realized[:data]['05/11']).to eq(12_500.0)
    expect(realized[:data]['10/11']).to eq(15_500.0)
    expect(expected[:data].size).to eq(30)
    expect(expected[:data]['02/11']).to eq(4_000.0)
    expect(expected[:data]['30/11']).to eq(100_000.0)
  end

  it 'has no third party row without an own fleet' do
    goals = described_class.new(tenant.billable_freights, goals: [], pace:, own_fleet: nil)

    expect(goals.third_party_row).to be_nil
    expect(goals.vehicle_rows).to be_empty
    expect(goals.required_daily_cents).to be_nil
  end
end
