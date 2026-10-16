require 'rails_helper'
require Rails.root.join('db/migrate/20261016142433_backfill_brasiltec_tonnage_rates')

RSpec.describe BackfillBrasiltecTonnageRates do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with two tenants with the Usiminas group' do
    let!(:tenant) { create(:tenant) }
    let!(:other_tenant) { create(:tenant) }

    before do
      create(:customer_group, tenant:, name: 'USIMINAS', terms: ['USIMINAS'])
      create(:customer_group, tenant: other_tenant, name: 'USIMINAS', terms: ['USIMINAS'])
    end

    it 'registers the Brasiltec rates of every tenant' do
      expect { migration.up }.to change(TonnageRate, :count).by(8)

      expect(tenant.tonnage_rates.pluck(:nickname)).to contain_exactly('Cubatão', 'Utinga', 'Ipatinga', 'TESP')
      expect(other_tenant.tonnage_rates.count).to eq(4)
    end

    it 'can run again without duplicating the rates' do
      migration.up

      expect { migration.up }.not_to change(TonnageRate, :count)
    end
  end
end
