require 'rails_helper'
require Rails.root.join('db/migrate/20261016142430_add_tonnage_rates_resource')

RSpec.describe AddTonnageRatesResource do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'without the tonnage rates resource' do
    it 'creates the writable tonnage rates resource' do
      expect { migration.up }.to change(Resource, :count).by(1)

      expect(Resource.pluck(:slug, :name, :writable)).to eq([['tonnage_rates', 'Custos por tonelada', true]])
    end

    it 'can run again without duplicating the resource' do
      migration.up

      expect { migration.up }.not_to change(Resource, :count)
    end
  end

  context 'when rolling back with permissions' do
    let!(:operator) { create(:user) }

    before do
      migration.up
      create(:access, user: operator, tenant: operator.tenant, resource: Resource.find_by!(slug: 'tonnage_rates'), reads: true)
    end

    it 'keeps the resource' do
      expect { migration.down }.not_to change(Resource, :count)
    end
  end
end
