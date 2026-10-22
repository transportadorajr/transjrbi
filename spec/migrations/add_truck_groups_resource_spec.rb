require 'rails_helper'
require Rails.root.join('db/migrate/20261022164324_add_truck_groups_resource')

RSpec.describe AddTruckGroupsResource do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'without the truck groups resource' do
    it 'creates the writable truck groups resource' do
      expect { migration.up }.to change(Resource, :count).by(1)

      expect(Resource.pluck(:slug, :name, :writable)).to eq([['truck_groups', 'Grupos de caminhões', true]])
    end

    it 'can run again without duplicating the resource' do
      migration.up

      expect { migration.up }.not_to change(Resource, :count)
    end
  end

  context 'when rolling back without permissions' do
    before { migration.up }

    it 'removes the resource' do
      expect { migration.down }.to change(Resource, :count).by(-1)
    end
  end

  context 'when rolling back with permissions' do
    let!(:operator) { create(:user) }

    before do
      migration.up
      create(:access, user: operator, tenant: operator.tenant, resource: Resource.find_by!(slug: 'truck_groups'), reads: true)
    end

    it 'keeps the resource' do
      expect { migration.down }.not_to change(Resource, :count)
    end
  end
end
