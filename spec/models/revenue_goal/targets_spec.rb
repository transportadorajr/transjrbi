require 'rails_helper'

RSpec.describe RevenueGoal::Targets do
  let(:tenant) { create(:tenant) }
  let(:month) { Date.new(2026, 11, 1) }
  let(:targets) { described_class.new(tenant, month) }

  let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
  let!(:arcelor) { create(:atua_customer, tenant:, name: 'ARCELORMITTAL', customer_group: usiminas) }
  let!(:gerdau) { create(:atua_customer, tenant:, name: 'GERDAU') }
  let!(:region) { create(:macro_region, tenant:, name: 'VALE DO AÇO/MG') }

  def freight(taker, freight_cents, issued_at, macro_region: nil)
    create(:atua_transport_document, tenant:, plate: 'AJR4391', taker_code: taker.code, origin_macro_region: macro_region, freight_cents:, issued_at:)
  end

  before do
    create(:own_fleet, tenant:, plates: %w[AJR4391])
    freight(arcelor, 500_000, Time.zone.local(2026, 10, 3, 10), macro_region: region)
    freight(gerdau, 200_000, Time.zone.local(2026, 10, 31, 23))
    freight(gerdau, 900_000, Time.zone.local(2026, 11, 2, 10))
    create(:atua_transport_document, tenant: create(:tenant), plate: 'AJR4391', freight_cents: 7_000_000, issued_at: Time.zone.local(2026, 10, 3, 10))
  end

  it 'lists the targets of each section by name' do
    expect(targets.options(:vehicles)).to eq('AJR4391' => 'AJR4391')
    expect(targets.options(:customer_groups)).to eq(usiminas.id.to_s => 'USIMINAS')
    expect(targets.options(:regions)).to eq(region.id.to_s => 'VALE DO AÇO/MG')
  end

  it 'sums the billing of the previous month by target' do
    expect(targets.reference_cents(:vehicles)).to eq('AJR4391' => 700_000)
    expect(targets.reference_cents(:customer_groups)).to eq(usiminas.id.to_s => 500_000, '' => 200_000)
    expect(targets.reference_cents(:regions)).to eq(region.id.to_s => 500_000, '' => 200_000)
  end

  it 'reads the goal amounts of the month by target' do
    create(:revenue_goal, :region, tenant:, month:, macro_region: region, amount_cents: 3_000_000)
    create(:revenue_goal, :customer_group, tenant:, month: month.prev_month, customer_group: usiminas)

    expect(targets.goal_amounts(:regions)).to eq(region.id.to_s => 3_000_000)
    expect(targets.goal_amounts(:customer_groups)).to be_empty
  end
end
