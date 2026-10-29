require 'rails_helper'

RSpec.describe ExcludedIssuerForm do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }

  before do
    create(:atua_transport_document, tenant:, issuer_code: 6190, issuer_name: 'MAYCON DORALINO SANTOS LORENA')
    create(:atua_transport_document, tenant:, issuer_code: 1951, issuer_name: 'JEFFERSON ANDRE REMONATTO')
    create(:atua_transport_document, tenant: other_tenant, issuer_code: 9166, issuer_name: 'MARLEI JULIA OLIVEIRA DA SILVA')
  end

  describe '#save' do
    context 'with an issuer of the tenant' do
      it 'excludes the issuer keeping the name from its documents' do
        form = described_class.new(tenant:, code: '6190')

        expect { form.save }.to change(ExcludedIssuer, :count).by(1)

        excluded_issuer = ExcludedIssuer.last
        expect(excluded_issuer.tenant).to eq(tenant)
        expect(excluded_issuer.code).to eq(6190)
        expect(excluded_issuer.name).to eq('MAYCON DORALINO SANTOS LORENA')
      end
    end

    context 'without an issuer' do
      it 'requires the issuer' do
        form = described_class.new(tenant:, code: '')

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to eq(['Emissor não pode ficar em branco'])
      end
    end

    context 'with an issuer that already is excluded' do
      before { create(:excluded_issuer, tenant:, code: 6190) }

      it 'rejects the issuer' do
        form = described_class.new(tenant:, code: '6190')

        expect { form.save }.not_to change(ExcludedIssuer, :count)
        expect(form.errors.full_messages).to eq(['Emissor já está desconsiderado'])
      end
    end

    context 'with an issuer of another tenant' do
      it 'rejects the issuer' do
        form = described_class.new(tenant:, code: '9166')

        expect { form.save }.not_to change(ExcludedIssuer, :count)
        expect(form.errors.full_messages).to eq(['Emissor não emitiu nenhum CT-e ou CE'])
      end
    end
  end

  describe '#issuer_options' do
    before { create(:excluded_issuer, tenant:, code: 1951) }

    it 'lists the issuers of the tenant that are still considered' do
      expect(described_class.new(tenant:).issuer_options).to eq([['MAYCON DORALINO SANTOS LORENA (6190)', 6190]])
    end
  end
end
