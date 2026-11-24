require 'rails_helper'
require Rails.root.join('db/migrate/20261118120900_backfill_own_fleet')

RSpec.describe BackfillOwnFleet do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with a tenant without an own fleet' do
    let!(:tenant) { create(:tenant) }

    it 'registers the plates of the own fleet' do
      expect { migration.up }.to change(OwnFleet, :count).by(1)

      expect(tenant.reload.own_fleet.plates.size).to eq(127)
    end

    context 'with the plates registered as trucks' do
      before do
        migration.up
        tenant.reload.own_fleet.plates.each { |plate| create(:atua_vehicle, tenant:, plate:) }
      end

      it 'lists the plates on the revenue goals of the month' do
        expect(RevenueGoal::Targets.new(tenant, Date.new(2026, 11, 1)).options(:vehicles).size).to eq(127)
      end
    end

    it 'can run again without duplicating the own fleet' do
      migration.up

      expect { migration.up }.not_to change(OwnFleet, :count)
    end
  end
end
