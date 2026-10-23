require 'rails_helper'
require Rails.root.join('db/migrate/20261022164328_backfill_truck_groups')

RSpec.describe BackfillTruckGroups do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with two tenants' do
    let!(:tenant) { create(:tenant) }
    let!(:other_tenant) { create(:tenant) }

    it 'registers the default groups of every tenant' do
      expect { migration.up }.to change(TruckGroup, :count).by(8)

      expect(tenant.truck_groups.count).to eq(4)
      expect(other_tenant.truck_groups.count).to eq(4)
    end

    it 'can run again without duplicating the groups' do
      migration.up

      expect { migration.up }.not_to change(TruckGroup, :count)
    end
  end
end
