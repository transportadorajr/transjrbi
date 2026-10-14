require 'rails_helper'
require Rails.root.join('db/migrate/20261014144702_add_tax_resources')

RSpec.describe AddTaxResources do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'without the tax resources' do
    it 'creates the read-only resources of CT-es and manifests' do
      expect { migration.up }.to change(Resource, :count).by(2)

      expect(Resource.order(:slug).pluck(:slug, :name, :writable)).to eq(
        [['manifests', 'Manifestos', false], ['transport_documents', 'CT-es', false]],
      )
    end

    it 'can run again without duplicating the resources' do
      migration.up

      expect { migration.up }.not_to change(Resource, :count)
    end
  end

  context 'with a resource already registered under the same slug' do
    let!(:resource) { create(:resource, name: 'Conhecimentos', slug: 'transport_documents', writable: true) }

    it 'keeps the existing resource untouched' do
      expect { migration.up }.to change(Resource, :count).by(1)

      expect(resource.reload.name).to eq('Conhecimentos')
      expect(resource.writable).to be(true)
    end
  end

  context 'when rolling back' do
    let!(:other_resource) { create(:resource, slug: 'users') }
    let!(:operator) { create(:user) }

    before do
      migration.up
      create(:access, user: operator, tenant: operator.tenant, resource: Resource.find_by!(slug: 'manifests'), reads: true)
    end

    it 'removes only the tax resources without permissions' do
      expect { migration.down }.to change(Resource, :count).by(-1)

      expect(Resource.pluck(:slug)).to contain_exactly('users', 'manifests')
    end
  end
end
