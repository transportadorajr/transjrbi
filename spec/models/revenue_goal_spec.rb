require 'rails_helper'

RSpec.describe RevenueGoal do
  let(:tenant) { create(:tenant) }

  describe 'validations' do
    it 'stores the first day of the month and the normalized plate' do
      goal = create(:revenue_goal, :vehicle, tenant:, month: Date.new(2026, 11, 18), plate: 'ajr-4391')

      expect(goal.month).to eq(Date.new(2026, 11, 1))
      expect(goal.plate).to eq('AJR4391')
    end

    it 'requires a positive amount' do
      goal = build(:revenue_goal, tenant:, amount_cents: 0)

      expect(goal).not_to be_valid
      expect(goal.errors[:amount_cents]).to be_present
    end

    it 'requires the plate only for a vehicle goal' do
      expect(build(:revenue_goal, tenant:, target_type: 'vehicle', plate: nil)).not_to be_valid
      expect(build(:revenue_goal, tenant:, plate: 'AJR4391')).not_to be_valid
    end

    it 'requires the plate for a trailer goal' do
      expect(build(:revenue_goal, tenant:, target_type: 'trailer', plate: nil)).not_to be_valid
      expect(create(:revenue_goal, :trailer, tenant:, plate: 'rhj-5a51').plate).to eq('RHJ5A51')
    end

    it 'keeps a vehicle and a trailer goal for the same plate apart' do
      create(:revenue_goal, :vehicle, tenant:, plate: 'RHJ5A51')

      expect(build(:revenue_goal, :trailer, tenant:, plate: 'RHJ5A51')).to be_valid
    end

    it 'requires the customer group only for a customer group goal' do
      expect(build(:revenue_goal, tenant:, target_type: 'customer_group')).not_to be_valid
      expect(build(:revenue_goal, :customer_group, tenant:)).to be_valid
    end

    it 'requires the macro region only for a region goal' do
      expect(build(:revenue_goal, tenant:, target_type: 'region')).not_to be_valid
      expect(build(:revenue_goal, :region, tenant:)).to be_valid
      expect(build(:revenue_goal, tenant:, macro_region: create(:macro_region, tenant:))).not_to be_valid
    end

    it 'requires the truck group only for a truck group goal' do
      expect(build(:revenue_goal, tenant:, target_type: 'truck_group')).not_to be_valid
      expect(build(:revenue_goal, :truck_group, tenant:)).to be_valid
      expect(build(:revenue_goal, tenant:, truck_group: create(:truck_group, tenant:))).not_to be_valid
    end

    it 'removes the truck group goals with the truck group' do
      goal = create(:revenue_goal, :truck_group, tenant:)

      expect { goal.truck_group.destroy! }.to change(described_class, :count).by(-1)
    end

    it 'removes the region goals with the macro region' do
      goal = create(:revenue_goal, :region, tenant:)

      expect { goal.macro_region.destroy! }.to change(described_class, :count).by(-1)
    end

    it 'allows a single goal per target in the month' do
      create(:revenue_goal, :vehicle, tenant:)

      expect(build(:revenue_goal, :vehicle, tenant:)).not_to be_valid
      expect(build(:revenue_goal, :vehicle, tenant:, plate: 'RHJ5A50')).to be_valid
      expect(build(:revenue_goal, :vehicle, tenant:, month: Date.current.next_month)).to be_valid
      expect(build(:revenue_goal, :vehicle, tenant: create(:tenant))).to be_valid

      region_goal = create(:revenue_goal, :region, tenant:)
      expect(build(:revenue_goal, tenant:, target_type: 'region', macro_region: region_goal.macro_region)).not_to be_valid
      expect(build(:revenue_goal, :region, tenant:, macro_region: create(:macro_region, tenant:, name: 'BAHIA', state: 'BA'))).to be_valid
    end

    it 'rejects an unknown target type' do
      expect(build(:revenue_goal, tenant:, target_type: 'driver')).not_to be_valid
    end
  end

  describe '#target_value' do
    it 'reads the column that identifies the target' do
      region_goal = create(:revenue_goal, :region, tenant:)

      expect(region_goal.target_value).to eq(region_goal.macro_region_id)
      expect(build(:revenue_goal, :vehicle, tenant:).target_value).to eq('AJR4391')
      expect(build(:revenue_goal, tenant:).target_value).to be_nil
    end
  end

  describe '.for_cut' do
    let(:month) { Date.new(2026, 11, 1) }
    let(:goals) { tenant.revenue_goals.for_month(month) }

    let!(:company_goal) { create(:revenue_goal, tenant:, month:) }
    let!(:vehicle_goal) { create(:revenue_goal, :vehicle, tenant:, month:, plate: 'AJR4391') }
    let!(:region_goal) { create(:revenue_goal, :region, tenant:, month:) }

    it 'finds the goal of the target of the cut' do
      expect(goals.for_cut({})).to eq(company_goal)
      expect(goals.for_cut({ plate: 'ajr-4391' })).to eq(vehicle_goal)
      expect(goals.for_cut({ macro_region_id: region_goal.macro_region_id.to_s })).to eq(region_goal)
    end

    it 'finds no goal for a cut without one' do
      expect(goals.for_cut({ plate: 'RHJ5A50' })).to be_nil
      expect(goals.for_cut({ macro_region_id: MacroRegion::OTHERS })).to be_nil
      expect(goals.for_cut({ product_group_id: 1 })).to be_nil
      expect(goals.for_cut({ plate: 'AJR4391', macro_region_id: region_goal.macro_region_id })).to be_nil
      expect(goals.for_cut({ driver_code: 11 })).to be_nil
      expect(tenant.revenue_goals.for_month(month.next_month).for_cut({})).to be_nil
    end
  end

  describe '.parse_month' do
    it 'reads a year and month' do
      expect(described_class.parse_month('2026-11')).to eq(Date.new(2026, 11, 1))
      expect(described_class.parse_month('2026-13')).to be_nil
      expect(described_class.parse_month('nov')).to be_nil
    end
  end
end
