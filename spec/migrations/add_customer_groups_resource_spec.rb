require 'rails_helper'
require Rails.root.join('db/migrate/20261014201016_add_customer_groups_resource')

RSpec.describe AddCustomerGroupsResource do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'without the customer groups resource' do
    it 'creates the writable resource of customer groups' do
      expect { migration.up }.to change(Resource, :count).by(1)

      expect(Resource.pluck(:slug, :name, :writable)).to eq([['customer_groups', 'Grupos de clientes', true]])
    end

    it 'can run again without duplicating the resource' do
      migration.up

      expect { migration.up }.not_to change(Resource, :count)
    end
  end

  context 'with a resource already registered under the same slug' do
    let!(:resource) { create(:resource, name: 'Grupos', slug: 'customer_groups', writable: false) }

    it 'keeps the existing resource untouched' do
      expect { migration.up }.not_to change(Resource, :count)

      expect(resource.reload.name).to eq('Grupos')
      expect(resource.writable).to be(false)
    end
  end

  context 'when rolling back' do
    let!(:other_resource) { create(:resource, slug: 'users') }

    before { migration.up }

    it 'removes only the customer groups resource' do
      expect { migration.down }.to change(Resource, :count).by(-1)

      expect(Resource.pluck(:slug)).to eq(['users'])
    end
  end

  context 'when rolling back with permissions on the customer groups resource' do
    let!(:operator) { create(:user) }

    before do
      migration.up
      create(:access, user: operator, tenant: operator.tenant, resource: Resource.find_by!(slug: 'customer_groups'), reads: true)
    end

    it 'keeps the resource' do
      expect { migration.down }.not_to change(Resource, :count)
    end
  end
end
