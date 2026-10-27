require 'rails_helper'

RSpec.describe Tenant do
  describe 'atua_url validation' do
    it 'accepts a blank url' do
      expect(build(:tenant, atua_url: nil)).to be_valid
    end

    it 'accepts an https url' do
      expect(build(:tenant, atua_url: 'https://transportadora.atua.com.br/adm')).to be_valid
    end

    it 'accepts a local http url' do
      expect(build(:tenant, atua_url: 'http://localhost:4567/adm')).to be_valid
    end

    it 'rejects a value that is not an http url' do
      tenant = build(:tenant, atua_url: 'transportadora.atua.com.br')

      expect(tenant).not_to be_valid
      expect(tenant.errors.full_messages).to eq(['URL da Atua não é válido'])
    end
  end

  describe '.by_name' do
    let!(:transjr) { create(:tenant, name: 'Transportadora JR Ltda', trade_name: 'TransJR') }
    let!(:rodominas) { create(:tenant, name: 'Rodoviário Minas S.A.', trade_name: 'RodoMinas') }

    it 'finds the tenants by the legal name' do
      expect(described_class.by_name('transportadora')).to eq([transjr])
    end

    it 'finds the tenants by the trade name' do
      expect(described_class.by_name('rodomin')).to eq([rodominas])
    end
  end

  describe '#owner' do
    let!(:tenant) { create(:tenant) }
    let!(:operator) { create(:user, tenant:, user_type: :operator) }
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    it 'returns the user with the owner profile' do
      expect(tenant.owner).to eq(owner)
    end
  end
end
