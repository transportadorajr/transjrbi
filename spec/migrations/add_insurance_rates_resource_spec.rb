require 'rails_helper'
require Rails.root.join('db/migrate/20261019144619_add_insurance_rates_resource')

RSpec.describe AddInsuranceRatesResource do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'without the insurance rates resource' do
    it 'creates the writable insurance rates resource' do
      expect { migration.up }.to change(Resource, :count).by(1)

      expect(Resource.pluck(:slug, :name, :writable)).to eq([['insurance_rates', 'Alíquotas de seguro', true]])
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
      create(:access, user: operator, tenant: operator.tenant, resource: Resource.find_by!(slug: 'insurance_rates'), reads: true)
    end

    it 'keeps the resource' do
      expect { migration.down }.not_to change(Resource, :count)
    end
  end
end
