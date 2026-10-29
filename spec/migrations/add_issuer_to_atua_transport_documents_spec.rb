require 'rails_helper'
require Rails.root.join('db/migrate/20261029130746_add_issuer_to_atua_transport_documents')

RSpec.describe AddIssuerToAtuaTransportDocuments do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  after { Atua::TransportDocument.reset_column_information }

  context 'when documents were imported with the issuer only in the raw data' do
    let!(:maycon) do
      create(:atua_transport_document, raw_data: { 'cd_pessoa_usuario' => 6190.0, 'nm_pessoa_usuario' => 'MAYCON DORALINO SANTOS LORENA' })
    end
    let!(:blank_name) { create(:atua_transport_document, raw_data: { 'cd_pessoa_usuario' => 1951, 'nm_pessoa_usuario' => ' ' }) }
    let!(:without_issuer) { create(:atua_transport_document, raw_data: { 'cd_pessoa_usuario' => nil }) }

    before do
      migration.down
      Atua::TransportDocument.reset_column_information
    end

    it 'copies the code and the name of the issuer into their own columns' do
      migration.up
      Atua::TransportDocument.reset_column_information

      expect(Atua::TransportDocument.order(:id).pluck(:issuer_code, :issuer_name)).to eq(
        [[6190, 'MAYCON DORALINO SANTOS LORENA'], [1951, nil], [nil, nil]],
      )
    end
  end
end
