require 'rails_helper'
require Rails.root.join('db/migrate/20261102182001_link_atua_value_complements')

RSpec.describe LinkAtuaValueComplements do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with a value complement whose unloading was entered under its own number' do
    let!(:tenant) { create(:tenant) }
    let!(:original) { create(:atua_transport_document, tenant:, number: '67991') }
    let!(:complement) do
      create(:atua_transport_document, tenant:, number: '68005', issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT, complemented_number: '67991')
    end
    let!(:unload) { create(:atua_expense, tenant:, history_code: 72, transport_document_number: '68005', cost_object: complement) }

    it 'links the complement to the original and moves the unloading to it' do
      migration.up

      expect(complement.reload.complemented_transport_document).to eq(original)
      expect(unload.reload.cost_object).to eq(original)
    end
  end
end
