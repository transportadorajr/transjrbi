require 'rails_helper'

RSpec.describe Atua::SaveExpensesCommand do
  let(:tenant) { create(:tenant) }
  let(:import) { create(:atua_import, tenant:, report_type: 'expenses', status_type: 'running', start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 13)) }
  let(:spreadsheet) { read_atua_fixture(:expenses) }

  context 'when Atua no longer reports an attachment stamped by a previous import' do
    let!(:expense) { create(:atua_expense, tenant:, code: 590_252, attachment_at: Time.zone.local(2026, 9, 1, 8)) }

    it 'clears the stamped date' do
      result = described_class.call(import, spreadsheet)

      expect(result).to have_attributes(inserted: 1216, updated: 1, removed: 0)
      expect(expense.reload).to have_attributes(attachment_at: nil, import:)
    end
  end

  context 'when a R$ 55,00 tarp lining was paid to Régio' do
    let!(:regio) { create(:customer_group, tenant:, name: 'RÉGIO', terms: ['MOINHO REGIO']) }
    let!(:cuiaba) { create(:atua_customer, tenant:, code: 7684, name: 'MOINHO REGIO ALIMENTOS S/A - CUIABA', customer_group: regio) }
    let!(:lining) do
      create(:atua_expense, tenant:, code: 1, posted_on: Date.new(2026, 9, 30), payee_code: 7684, history_code: 72, total_cents: 5_500)
    end

    it 'discards it after saving the report' do
      described_class.call(import, spreadsheet)

      expect(lining.reload.removed_from_atua_at).to be_present
    end
  end

  it 'is the save command of the expenses report' do
    expect(Atua::SaveReportCommand.for(:expenses)).to eq(described_class)
  end
end
