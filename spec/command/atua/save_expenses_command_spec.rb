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

  it 'is the save command of the expenses report' do
    expect(Atua::SaveReportCommand.for(:expenses)).to eq(described_class)
  end
end
