require 'rails_helper'
require Rails.root.join('db/migrate/20261103194304_backfill_atua_forklift_expenses')

RSpec.describe BackfillAtuaForkliftExpenses do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with a forklift expense pointing at a transport document number' do
    let!(:tenant) { create(:tenant) }
    let!(:transport_document) { create(:atua_transport_document, tenant:, number: '75120', freight_cents: 500_000) }
    let!(:forklift) do
      create(:atua_expense, tenant:, history_code: 476, history_name: 'EMPILHADEIRA / MOV CARGA', document_number: '75120',
                            total_cents: 20_000)
    end

    it 'links the forklift expense to the freight of its document number' do
      migration.up

      expect(forklift.reload.transport_document_number).to eq('75120')
      expect(forklift.cost_object).to eq(transport_document)
      expect(transport_document.expenses).to eq([forklift])
    end

    it 'deducts the forklift expense from the gross freight of the transport document' do
      migration.up

      totals = Atua::TransportDocument.where(tenant:).with_freight_totals.index_by(&:number)

      expect(totals['75120'].freight_cents).to eq(500_000)
      expect(totals['75120'].net_cents).to eq(480_000)
    end

    it 'can run again without changing the links' do
      migration.up

      expect { migration.up }.not_to(change { Atua::Expense.order(:id).pluck(:cost_object_type, :cost_object_id, :updated_at) })
    end
  end
end
