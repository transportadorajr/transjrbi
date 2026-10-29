require 'rails_helper'

RSpec.describe ExcludedIssuer do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }

  describe 'validations' do
    context 'with an issuer already excluded' do
      let!(:excluded_issuer) { create(:excluded_issuer, tenant:, code: 6190) }

      it 'rejects the same code twice in the tenant' do
        duplicate = build(:excluded_issuer, tenant:, code: 6190)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:code]).to eq(['já está em uso'])
      end

      it 'accepts the same code in another tenant' do
        expect(build(:excluded_issuer, tenant: other_tenant, code: 6190)).to be_valid
      end
    end

    it 'requires the code and the name' do
      excluded_issuer = described_class.new(tenant:)

      expect(excluded_issuer).not_to be_valid
      expect(excluded_issuer.errors.attribute_names).to contain_exactly(:code, :name)
    end
  end

  describe 'scopes' do
    context 'with documents issued by the excluded issuers' do
      let!(:maycon) { create(:excluded_issuer, tenant:, code: 6190, name: 'MAYCON DORALINO SANTOS LORENA') }
      let!(:jefferson) { create(:excluded_issuer, tenant:, code: 1951, name: 'JEFFERSON ANDRE REMONATTO') }

      before do
        create(:atua_transport_document, tenant:, document_kind: 'ce', issuer_code: 6190, freight_cents: 1_657_920)
        create(:atua_transport_document, tenant:, document_kind: 'ce', issuer_code: 6190, freight_cents: 1_547_680)
        create(:atua_transport_document, tenant:, document_kind: 'ce', issuer_code: 6190, freight_cents: 900_000,
                                         canceled_at: Time.zone.local(2026, 10, 2))
        create(:atua_transport_document, tenant:, issuer_code: 6001, freight_cents: 500_000)
        create(:atua_transport_document, tenant: other_tenant, issuer_code: 6190, freight_cents: 700_000)
      end

      it 'sums the documents and the freight of each issuer leaving out the canceled ones' do
        totals = described_class.with_document_totals.order(:name).map { |issuer| [issuer.name, issuer.documents_count, issuer.freight] }

        expect(totals).to eq(
          [['JEFFERSON ANDRE REMONATTO', 0, Money.from_cents(0)], ['MAYCON DORALINO SANTOS LORENA', 2, Money.from_cents(3_205_600)]],
        )
        expect(described_class.count).to eq(2)
      end

      it 'filters by the name' do
        expect(described_class.by_name('jeff')).to eq([jefferson])
        expect(described_class.by_name('lorena')).to eq([maycon])
      end
    end
  end

  describe '.available_issuers' do
    context 'with documents of several issuers' do
      before do
        create(:excluded_issuer, tenant:, code: 6190)
        create(:atua_transport_document, tenant:, issuer_code: 6190, issuer_name: 'MAYCON DORALINO SANTOS LORENA')
        create(:atua_transport_document, tenant:, issuer_code: 1951, issuer_name: 'JEFFERSON ANDRE REMONATTO')
        create(:atua_transport_document, tenant:, issuer_code: 1951, issuer_name: 'JEFFERSON ANDRE REMONATTO')
        create(:atua_transport_document, tenant:, issuer_code: 6001, issuer_name: 'EMISSAO CTE')
        create(:atua_transport_document, tenant:, issuer_code: nil, issuer_name: nil)
        create(:atua_transport_document, tenant: other_tenant, issuer_code: 9166, issuer_name: 'MARLEI JULIA OLIVEIRA DA SILVA')
      end

      it 'lists each issuer of the tenant once by name leaving out the excluded ones' do
        expect(described_class.available_issuers(tenant)).to eq([['EMISSAO CTE', 6001], ['JEFFERSON ANDRE REMONATTO', 1951]])
      end
    end
  end
end
