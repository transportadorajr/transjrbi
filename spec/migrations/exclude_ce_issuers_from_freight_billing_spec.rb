require 'rails_helper'
require Rails.root.join('db/migrate/20261029134512_exclude_ce_issuers_from_freight_billing')

RSpec.describe ExcludeCeIssuersFromFreightBilling do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }

  context 'when the tenants have documents of the CE issuers' do
    before do
      create(:atua_transport_document, tenant:, document_kind: 'ce', issuer_code: 6190, issuer_name: 'MAYCON DORALINO SANTOS LORENA')
      create(:atua_transport_document, tenant:, document_kind: 'ce', issuer_code: 6190, issuer_name: 'MAYCON DORALINO SANTOS LORENA')
      create(:atua_transport_document, tenant:, document_kind: 'ce', issuer_code: 1951, issuer_name: 'JEFFERSON ANDRE REMONATTO')
      create(:atua_transport_document, tenant:, issuer_code: 6001, issuer_name: 'EMISSAO CTE')
      create(:atua_transport_document, tenant: other_tenant, issuer_code: 6001, issuer_name: 'EMISSAO CTE')
    end

    it 'excludes both issuers only in the tenants that have their documents' do
      expect { migration.up }.to change(ExcludedIssuer, :count).by(2)

      expect(ExcludedIssuer.order(:code).pluck(:tenant_id, :code, :name)).to eq(
        [[tenant.id, 1951, 'JEFFERSON ANDRE REMONATTO'], [tenant.id, 6190, 'MAYCON DORALINO SANTOS LORENA']],
      )
    end

    it 'can run again without duplicating the issuers' do
      migration.up

      expect { migration.up }.not_to change(ExcludedIssuer, :count)
    end

    it 'considers the issuers again when rolled back' do
      migration.up
      create(:excluded_issuer, tenant:, code: 6001, name: 'EMISSAO CTE')

      expect { migration.down }.to change(ExcludedIssuer, :count).by(-2)
      expect(ExcludedIssuer.pluck(:code)).to eq([6001])
    end
  end
end
