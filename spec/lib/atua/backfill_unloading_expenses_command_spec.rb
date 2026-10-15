require 'rails_helper'

RSpec.describe Atua::BackfillUnloadingExpensesCommand do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  context 'with unloading expenses imported before they were linked by the freight number' do
    let!(:truck) { create(:atua_vehicle, tenant:, code: 812, plate: 'EXU0F72') }
    let!(:transport_document) { create(:atua_transport_document, tenant:, code: 80_512, number: '74158') }
    let!(:guide) { create(:atua_transport_document, tenant:, code: 80_513, number: '74159') }
    let!(:unload) { create(:atua_expense, tenant:, history_code: 72, document_number: '74158', plate: 'EXU0F72', cost_object: truck) }
    let!(:guide_unload) { create(:atua_expense, tenant:, history_code: 72, document_number: '74159 GUIA', plate: 'EXU0F72') }
    let!(:damage) { create(:atua_expense, tenant:, history_code: 474, document_number: '74158') }
    let!(:voucher) { create(:atua_expense, tenant:, history_code: 72, document_number: 'VALE DESCARGA', plate: 'EXU0F72') }
    let!(:fuel) { create(:atua_expense, tenant:, history_code: 434, document_number: '74158', plate: 'EXU0F72') }
    let!(:stranger) { create(:atua_expense, tenant: other_tenant, history_code: 72, document_number: '74158') }

    it 'fills the freight number of the unloading expenses and links them to the freight' do
      described_class.call(tenant)

      expect(unload.reload).to have_attributes(transport_document_number: '74158', cost_object: transport_document)
      expect(guide_unload.reload).to have_attributes(transport_document_number: '74159', cost_object: guide)
      expect(damage.reload).to have_attributes(transport_document_number: '74158', cost_object: transport_document)
      expect(voucher.reload).to have_attributes(transport_document_number: nil, cost_object: truck)
      expect(fuel.reload).to have_attributes(transport_document_number: nil, cost_object: truck)
      expect(stranger.reload).to have_attributes(transport_document_number: nil, cost_object: nil)
    end

    it 'can run again without changing the expenses' do
      described_class.call(tenant)

      expect { described_class.call(tenant) }
        .not_to(change { Atua::Expense.order(:id).pluck(:transport_document_number, :cost_object_type, :cost_object_id, :updated_at) })
    end
  end

  context 'with an expense that already carries the freight code' do
    let!(:transport_document) { create(:atua_transport_document, tenant:, code: 80_512, number: '74158') }
    let!(:unload) { create(:atua_expense, tenant:, history_code: 72, document_number: '74159', transport_document_code: 80_512) }

    it 'keeps the freight of the code' do
      described_class.call(tenant)

      expect(unload.reload).to have_attributes(transport_document_number: nil, cost_object: transport_document)
    end
  end
end
