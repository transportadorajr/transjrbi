require 'rails_helper'
require Rails.root.join('db/migrate/20261027195356_recreate_atua_manifest_documents_source_key_with_nulls_not_distinct')

RSpec.describe RecreateAtuaManifestDocumentsSourceKeyWithNullsNotDistinct do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  after { migration.up if ActiveRecord::Base.connection.select_value(nulls_distinct_query) }

  let(:nulls_distinct_query) do
    "SELECT indnullsnotdistinct = false FROM pg_index WHERE indexrelid = '#{described_class::INDEX_NAME}'::regclass"
  end

  context 'when a document without series was imported twice in the same manifest' do
    let!(:tenant) { create(:tenant) }
    let!(:document) { create(:atua_manifest_document, tenant:, manifest_code: 41_236, transport_document_number: '74130', transport_document_series: nil) }
    let!(:other_document) { create(:atua_manifest_document, tenant:, manifest_code: 41_236, transport_document_number: '74131', transport_document_series: nil) }

    before do
      migration.down
      Atua::ManifestDocument.insert_all([document.attributes.except('id', 'created_at', 'updated_at')])
    end

    it 'keeps a single copy and blocks new duplicates' do
      expect { migration.up }.to change(Atua::ManifestDocument, :count).from(3).to(2)

      expect(Atua::ManifestDocument.where(transport_document_number: '74130').count).to eq(1)
      expect(other_document.reload).to be_persisted
      expect { Atua::ManifestDocument.insert_all([document.attributes.except('id', 'created_at', 'updated_at')]) }
        .not_to change(Atua::ManifestDocument, :count)
    end
  end
end
