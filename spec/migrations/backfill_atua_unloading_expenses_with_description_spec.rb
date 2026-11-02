require 'rails_helper'
require Rails.root.join('db/migrate/20261102224203_backfill_atua_unloading_expenses_with_description')

RSpec.describe BackfillAtuaUnloadingExpensesWithDescription do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with unloading expenses described after the transport document number' do
    let!(:tenant) { create(:tenant) }
    let!(:transport_document) { create(:atua_transport_document, tenant:, number: '75010') }
    let!(:short_document) { create(:atua_transport_document, tenant:, number: '190') }
    let!(:advance) { create(:atua_expense, tenant:, history_code: 72, document_number: '75010 ANTECIPAÇÃO') }
    let!(:short) { create(:atua_expense, tenant:, history_code: 72, document_number: '190 chapa ibirarema') }

    it 'links the unloading expense to the freight of its document number' do
      migration.up

      expect(advance.reload.transport_document_number).to eq('75010')
      expect(advance.cost_object).to eq(transport_document)
      expect(short.reload.transport_document_number).to be_nil
      expect(short.cost_object).not_to eq(short_document)
    end

    it 'can run again without changing the links' do
      migration.up

      expect { migration.up }.not_to(change { Atua::Expense.order(:id).pluck(:cost_object_type, :cost_object_id, :updated_at) })
    end
  end
end
