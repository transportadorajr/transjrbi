require 'rails_helper'
require Rails.root.join('db/migrate/20261019210828_add_freight_billing_resource')

RSpec.describe AddFreightBillingResource do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'without the freight billing resource' do
    it 'creates the read-only freight billing resource' do
      expect { migration.up }.to change(Resource, :count).by(1)

      expect(Resource.pluck(:slug, :name, :writable)).to eq([['freight_billing', 'Faturamento de fretes', false]])
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
      create(:access, user: operator, tenant: operator.tenant, resource: Resource.find_by!(slug: 'freight_billing'), reads: true)
    end

    it 'keeps the resource' do
      expect { migration.down }.not_to change(Resource, :count)
    end
  end
end
