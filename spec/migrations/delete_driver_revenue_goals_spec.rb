require 'rails_helper'
require Rails.root.join('db/migrate/20261118124619_delete_driver_revenue_goals')

RSpec.describe DeleteDriverRevenueGoals do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with goals by driver and by vehicle' do
    let!(:tenant) { create(:tenant) }
    let!(:vehicle_goal) { create(:revenue_goal, :vehicle, tenant:) }

    before do
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        INSERT INTO revenue_goals (tenant_id, month, target_type, driver_code, amount_cents, created_at, updated_at)
        VALUES (#{tenant.id}, '2026-11-01', 'driver', 11, 3000000, NOW(), NOW())
      SQL
    end

    it 'deletes only the goals by driver' do
      expect { migration.up }.to change(RevenueGoal, :count).by(-1)

      expect(RevenueGoal.pluck(:id)).to eq([vehicle_goal.id])
    end
  end
end
