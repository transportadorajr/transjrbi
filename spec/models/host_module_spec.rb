require 'rails_helper'

describe HostModule do
  describe '.find_by_subdomain' do
    it 'finds the maintenance module' do
      host_module = described_class.find_by_subdomain('manutencao')

      expect(host_module.key).to eq(:maintenance)
      expect(host_module.resources).to eq(Ability::MAINTENANCE_RESOURCES)
      expect(host_module.feature).to eq(:maintenance)
    end

    it 'finds the HR module' do
      host_module = described_class.find_by_subdomain('rh')

      expect(host_module.key).to eq(:hr)
      expect(host_module.resources).to eq(%i[hr employees])
      expect(host_module.feature).to eq(:hr)
    end

    it 'returns nil for the app subdomain' do
      expect(described_class.find_by_subdomain('app')).to be_nil
    end
  end

  describe '#enabled?' do
    let(:tenant) { create(:tenant) }
    let(:host_module) { described_class.find_by_subdomain('rh') }

    it 'is disabled when the flag is off for the tenant' do
      expect(host_module.enabled?(tenant)).to be(false)
    end

    it 'is enabled when the flag is on for the tenant' do
      Flipper.enable_actor(:hr, tenant)

      expect(host_module.enabled?(tenant)).to be(true)
    end
  end
end
