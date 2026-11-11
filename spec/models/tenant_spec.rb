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

  describe '#billable_freights' do
    let(:tenant) { create(:tenant) }
    let!(:freight) { create(:atua_transport_document, tenant:) }
    let!(:without_issuer) { create(:atua_transport_document, tenant:, issuer_code: nil) }

    before do
      create(:excluded_issuer, tenant:, code: 77, name: 'ROBO')
      create(:atua_transport_document, tenant:, issuer_code: 77)
      create(:atua_transport_document, tenant:, vehicle_sale: true)
      create(:atua_transport_document)
    end

    it 'lists the freights of the tenant out of the excluded issuers' do
      expect(tenant.billable_freights).to contain_exactly(freight, without_issuer)
    end
  end

  describe '#last_synced_at' do
    let(:tenant) { create(:tenant) }

    it 'returns the end of the last succeeded import' do
      create(:atua_import, tenant:, status_type: 'succeeded', finished_at: Time.zone.local(2026, 11, 11, 14))
      create(:atua_import, tenant:, status_type: 'failed', finished_at: Time.zone.local(2026, 11, 11, 15))
      create(:atua_import, status_type: 'succeeded', finished_at: Time.zone.local(2026, 11, 11, 16))

      expect(tenant.last_synced_at).to eq(Time.zone.local(2026, 11, 11, 14))
    end

    it 'is nil before the first import' do
      expect(tenant.last_synced_at).to be_nil
    end
  end
end
