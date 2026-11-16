require 'rails_helper'

RSpec.describe RevenueGoal::Week do
  let(:tenant) { create(:tenant) }
  let(:customer_group) { create(:customer_group, tenant:) }

  def goal(month, amount_cents, **)
    build(:revenue_goal, tenant:, month:, amount_cents:, **)
  end

  it 'spreads the month goal over the business days of the week' do
    week = described_class.new(Date.new(2026, 11, 10), goals: [goal(Date.new(2026, 11, 1), 2_500_000)], holidays: {})

    expect(week.period).to eq(Date.new(2026, 11, 8)..Date.new(2026, 11, 14))
    expect(week.goal_cents(:company)).to eq(600_000)
  end

  it 'takes each day from the goal of its own month' do
    goals = [goal(Date.new(2026, 9, 1), 2_500_000), goal(Date.new(2026, 10, 1), 2_700_000)]
    holidays = { Date.new(2026, 10, 2) => build(:holiday, date: Date.new(2026, 10, 2)) }
    week = described_class.new(Date.new(2026, 10, 1), goals:, holidays:)

    expect(week.months).to eq([Date.new(2026, 9, 1), Date.new(2026, 10, 1)])
    expect(week.goal_cents(:company)).to eq(496_154)
  end

  it 'finds the goal of each target' do
    goals = [goal(Date.new(2026, 11, 1), 2_500_000, target_type: 'vehicle', plate: 'AJR4391'),
             goal(Date.new(2026, 11, 1), 5_000_000, target_type: 'customer_group', customer_group:)]
    week = described_class.new(Date.new(2026, 11, 10), goals:, holidays: {})

    expect(week.goal_cents(:vehicle, plate: 'AJR4391')).to eq(600_000)
    expect(week.goal_cents(:customer_group, customer_group_id: customer_group.id)).to eq(1_200_000)
    expect(week.goal_cents(:company)).to be_nil
  end
end
