require 'rails_helper'

RSpec.describe CompanyForm do
  let(:tenant) do
    create(:tenant, name: 'Teste Ltda', trade_name: 'Teste', legal_id: '11.111.111/0001-11', atua_url: 'https://teste.atua.com.br',
                    atua_device_token: 'token-antigo', atua_device_hash: 'hash-antigo')
  end

  describe '.for_tenant' do
    it 'fills the form with the tenant data except the secrets' do
      form = described_class.for_tenant(tenant)

      expect(form).to have_attributes(name: 'Teste Ltda', trade_name: 'Teste', legal_id: '11.111.111/0001-11',
                                      atua_url: 'https://teste.atua.com.br', atua_device_token: nil, atua_device_hash: nil)
      expect(form).to be_persisted
    end
  end

  describe '#save' do
    it 'updates the tenant with the normalized data' do
      form = described_class.for_tenant(tenant)
      form.assign_attributes(name: ' Transportadora  JR Ltda ', trade_name: ' TransJR ', legal_id: ' 33.333.333/0001-33 ',
                             atua_url: ' https://transjr.atua.com.br/ ', atua_device_token: ' token-novo ', atua_device_hash: ' hash-novo ')

      expect(form.save).to be(true)
      expect(tenant.reload).to have_attributes(name: 'Transportadora JR Ltda', trade_name: 'TransJR', legal_id: '33.333.333/0001-33',
                                               atua_url: 'https://transjr.atua.com.br', atua_device_token: 'token-novo',
                                               atua_device_hash: 'hash-novo')
    end

    it 'keeps the current secrets when they are left blank' do
      form = described_class.for_tenant(tenant)
      form.assign_attributes(atua_device_token: '', atua_device_hash: ' ')

      expect(form.save).to be(true)
      expect(tenant.reload).to have_attributes(atua_device_token: 'token-antigo', atua_device_hash: 'hash-antigo')
    end

    it 'clears the Atua url when it is left blank' do
      form = described_class.for_tenant(tenant)
      form.atua_url = ''

      expect(form.save).to be(true)
      expect(tenant.reload.atua_url).to be_nil
    end

    it 'rejects the data without the required fields' do
      form = described_class.for_tenant(tenant)
      form.assign_attributes(name: ' ', trade_name: '', legal_id: '', atua_url: 'ftp://atua')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to contain_exactly(
        'Razão social não pode ficar em branco', 'Nome fantasia não pode ficar em branco', 'CNPJ não pode ficar em branco',
        'URL da Atua não é válido'
      )
      expect(tenant.reload.name).to eq('Teste Ltda')
    end

    it 'rejects a legal id of another tenant' do
      other_tenant = create(:tenant, legal_id: '22.222.222/0001-22')
      form = described_class.for_tenant(tenant)
      form.legal_id = other_tenant.legal_id

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to contain_exactly('CNPJ já está em uso')
    end
  end
end
