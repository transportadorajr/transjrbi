require 'rails_helper'

RSpec.describe RevenueGoals::ReplicateMonthCommand do
  let(:tenant) { create(:tenant) }
  let(:month) { Date.new(2026, 11, 1) }

  before do
    create(:revenue_goal, tenant:, month: month.prev_month, amount_cents: 10_000_000)
    create(:revenue_goal, :vehicle, tenant:, month: month.prev_month, plate: 'AJR4391', amount_cents: 1_000_000)
    create(:revenue_goal, :vehicle, tenant:, month: month.prev_month, plate: 'RHJ5A50', amount_cents: 2_000_000)
    create(:revenue_goal, :vehicle, tenant:, month:, plate: 'RHJ5A50', amount_cents: 2_500_000)
    create(:revenue_goal, tenant: create(:tenant), month: month.prev_month, amount_cents: 7_000_000)
  end

  it 'copies the goals of the previous month that are missing in the month' do
    expect { described_class.call(tenant, month) }.to change(RevenueGoal, :count).by(2)

    expect(tenant.revenue_goals.for_month(month).map { [it.target_type, it.plate, it.amount_cents] })
      .to contain_exactly(['company', nil, 10_000_000], ['vehicle', 'AJR4391', 1_000_000], ['vehicle', 'RHJ5A50', 2_500_000])
  end

  it 'copies nothing when it runs again' do
    described_class.call(tenant, month)

    expect { expect(described_class.call(tenant, month)).to be_empty }.not_to change(RevenueGoal, :count)
  end
end
