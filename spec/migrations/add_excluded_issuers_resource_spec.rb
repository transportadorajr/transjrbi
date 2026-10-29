require 'rails_helper'
require Rails.root.join('db/migrate/20261029130748_add_excluded_issuers_resource')

RSpec.describe AddExcludedIssuersResource do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'without the excluded issuers resource' do
    it 'creates the writable excluded issuers resource' do
      expect { migration.up }.to change(Resource, :count).by(1)

      expect(Resource.pluck(:slug, :name, :writable)).to eq([['excluded_issuers', 'Emissores desconsiderados', true]])
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
      create(:access, user: operator, tenant: operator.tenant, resource: Resource.find_by!(slug: 'excluded_issuers'), reads: true)
    end

    it 'keeps the resource' do
      expect { migration.down }.not_to change(Resource, :count)
    end
  end
end
