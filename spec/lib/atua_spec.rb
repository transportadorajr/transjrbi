require 'rails_helper'

RSpec.describe Atua do
  context 'with the import enabled for one tenant' do
    let!(:enabled_tenant) { create(:tenant) }
    let!(:disabled_tenant) { create(:tenant) }

    before { Flipper.enable_actor(described_class::FEATURE, enabled_tenant) }

    it 'returns only the enabled tenants' do
      expect(Tenant.count).to eq(2)
      expect(described_class.enabled_tenants).to eq([enabled_tenant])
    end

    it 'checks the flag by tenant' do
      expect(described_class.enabled?(enabled_tenant)).to be(true)
      expect(described_class.enabled?(disabled_tenant)).to be(false)
    end
  end

  context 'with the import enabled for everyone', flipper: :atua_import do
    let!(:tenants) { create_list(:tenant, 2) }

    it 'returns every tenant' do
      expect(described_class.enabled_tenants).to match_array(tenants)
    end
  end

  context 'with the import disabled' do
    before { create(:tenant) }

    it 'returns no tenant' do
      expect(described_class.enabled_tenants).to be_empty
    end
  end
end
