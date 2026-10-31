require 'rails_helper'
require Rails.root.join('db/migrate/20261031134859_discard_internal_taker_transport_documents')

RSpec.describe DiscardInternalTakerTransportDocuments do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with an imported document taken by Transjr' do
    let!(:tenant) { create(:tenant) }
    let!(:taker) { create(:atua_customer, tenant:, document_digits: '10212838000283') }
    let!(:document) { create(:atua_transport_document, tenant:, taker_code: taker.code) }

    it 'removes the document' do
      migration.up

      expect(document.reload.removed_from_atua_at).to be_present
    end
  end
end
