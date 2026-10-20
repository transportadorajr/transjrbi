require 'rails_helper'
require Rails.root.join('db/migrate/20261019180009_replace_due_on_with_due_dates_on_atua_transport_documents')

RSpec.describe ReplaceDueOnWithDueDatesOnAtuaTransportDocuments do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  after { Atua::TransportDocument.reset_column_information }

  context 'when documents were imported with a single due date' do
    let!(:document) { create(:atua_transport_document) }
    let!(:document_without_due_date) { create(:atua_transport_document) }

    before do
      migration.down
      Atua::TransportDocument.reset_column_information
      ActiveRecord::Base.connection.execute("UPDATE atua_transport_documents SET due_on = '2026-10-29' WHERE id = #{document.id}")
    end

    it 'moves the due date into the list of due dates' do
      migration.up
      Atua::TransportDocument.reset_column_information

      expect(Atua::TransportDocument.column_names).not_to include('due_on')
      expect(document.reload.due_dates).to eq([Date.new(2026, 10, 29)])
      expect(document_without_due_date.reload.due_dates).to eq([])
    end
  end
end
