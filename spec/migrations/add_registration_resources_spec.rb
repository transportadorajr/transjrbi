require 'rails_helper'
require Rails.root.join('db/migrate/20261014165027_add_registration_resources')

RSpec.describe AddRegistrationResources do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'without the registration resources' do
    it 'creates the read-only resources of customers, drivers and vehicles' do
      expect { migration.up }.to change(Resource, :count).by(3)

      expect(Resource.order(:slug).pluck(:slug, :name, :writable)).to eq(
        [['customers', 'Clientes', false], ['drivers', 'Motoristas', false], ['vehicles', 'Veículos', false]],
      )
    end

    it 'can run again without duplicating the resources' do
      migration.up

      expect { migration.up }.not_to change(Resource, :count)
    end
  end

  context 'with a resource already registered under the same slug' do
    let!(:resource) { create(:resource, name: 'Frota', slug: 'vehicles', writable: true) }

    it 'keeps the existing resource untouched' do
      expect { migration.up }.to change(Resource, :count).by(2)

      expect(resource.reload.name).to eq('Frota')
      expect(resource.writable).to be(true)
    end
  end

  context 'when rolling back' do
    let!(:other_resource) { create(:resource, slug: 'users') }
    let!(:operator) { create(:user) }

    before do
      migration.up
      create(:access, user: operator, tenant: operator.tenant, resource: Resource.find_by!(slug: 'drivers'), reads: true)
    end

    it 'removes only the registration resources without permissions' do
      expect { migration.down }.to change(Resource, :count).by(-2)

      expect(Resource.pluck(:slug)).to contain_exactly('users', 'drivers')
    end
  end
end
