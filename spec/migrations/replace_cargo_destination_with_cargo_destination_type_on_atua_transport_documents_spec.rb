require 'rails_helper'
require Rails.root.join('db/migrate/20261104171507_replace_cargo_destination_with_cargo_destination_type_on_atua_transport_documents')

RSpec.describe ReplaceCargoDestinationWithCargoDestinationTypeOnAtuaTransportDocuments do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  after { Atua::TransportDocument.reset_column_information }

  context 'when documents were imported with the cargo destination as text' do
    let!(:national) { create(:atua_transport_document) }
    let!(:export) { create(:atua_transport_document) }
    let!(:import) { create(:atua_transport_document) }
    let!(:without_destination) { create(:atua_transport_document) }

    before do
      migration.down
      Atua::TransportDocument.reset_column_information
      { national => 'Nacional', export => 'Exportação', import => 'Importação' }.each do |document, destination|
        ActiveRecord::Base.connection.execute("UPDATE atua_transport_documents SET cargo_destination = '#{destination}' WHERE id = #{document.id}")
      end
    end

    it 'moves the text into the cargo destination type' do
      migration.up
      Atua::TransportDocument.reset_column_information

      expect(Atua::TransportDocument.column_names).not_to include('cargo_destination')
      expect(national.reload.cargo_destination_type).to eq('national')
      expect(export.reload.cargo_destination_type).to eq('export')
      expect(import.reload.cargo_destination_type).to eq('import')
      expect(without_destination.reload.cargo_destination_type).to be_nil
    end
  end
end
