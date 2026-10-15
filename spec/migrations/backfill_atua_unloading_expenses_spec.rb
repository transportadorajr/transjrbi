require 'rails_helper'
require Rails.root.join('db/migrate/20261015145709_backfill_atua_unloading_expenses')

RSpec.describe BackfillAtuaUnloadingExpenses do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }
  let!(:transport_document) { create(:atua_transport_document, tenant:, number: '74158') }
  let!(:stranger_document) { create(:atua_transport_document, tenant: other_tenant, number: '74158') }
  let!(:unload) { create(:atua_expense, tenant:, history_code: 72, document_number: '74158') }
  let!(:stranger) { create(:atua_expense, tenant: other_tenant, history_code: 474, document_number: '74158 CHAPA GUIA') }

  it 'links the unloading expenses of every tenant to the freight of their document number' do
    migration.up

    expect(unload.reload.cost_object).to eq(transport_document)
    expect(stranger.reload.cost_object).to eq(stranger_document)
  end

  it 'can run again without changing the links' do
    migration.up

    expect { migration.up }.not_to(change { Atua::Expense.order(:id).pluck(:cost_object_type, :cost_object_id, :updated_at) })
  end
end
