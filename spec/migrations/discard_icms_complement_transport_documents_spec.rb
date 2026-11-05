require 'rails_helper'
require Rails.root.join('db/migrate/20261105210741_discard_icms_complement_transport_documents')

RSpec.describe DiscardIcmsComplementTransportDocuments do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with an imported value complement of ICMS only' do
    let!(:tenant) { create(:tenant) }
    let!(:document) do
      create(:atua_transport_document, tenant:, issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT, freight_cents: 6_514, icms_cents: 6_514)
    end

    it 'removes the document' do
      migration.up

      expect(document.reload.removed_from_atua_at).to be_present
    end
  end
end
