require 'rails_helper'

RSpec.describe RevenueProjection::Snapshot do
  let(:tenant) { create(:tenant) }

  it 'validates the period type' do
    snapshot = build(:revenue_projection_snapshot, tenant:, period_type: 'year')

    expect(snapshot).not_to be_valid
    expect(snapshot.errors.attribute_names).to contain_exactly(:period_type)
  end

  it 'stores a single snapshot of each period per day' do
    create(:revenue_projection_snapshot, tenant:)
    create(:revenue_projection_snapshot, tenant:, period_type: 'week', period_start: Date.new(2026, 11, 8))

    expect { create(:revenue_projection_snapshot, tenant:) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'exposes the amounts as money' do
    snapshot = build(:revenue_projection_snapshot)

    expect([snapshot.realized, snapshot.projected, snapshot.low, snapshot.high])
      .to eq([Money.from_cents(1_000_000), Money.from_cents(2_300_000), Money.from_cents(2_100_000), Money.from_cents(2_500_000)])
  end

  it 'translates every period type' do
    expect(described_class.period_types.keys.map { described_class.human_enum_name(:period_type, it) }).to eq(%w[Mês Semana])
  end
end
