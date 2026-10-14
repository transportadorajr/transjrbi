require 'rails_helper'

RSpec.describe Atua::SaveCustomersCommand do
  let(:tenant) { create(:tenant) }
  let(:import) { create(:atua_import, tenant:, report_type: 'customers', status_type: 'running', start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 13)) }
  let(:spreadsheet) { read_atua_fixture(:customers) }
  let(:code) { Atua::MapCustomersCommand.call(tenant, spreadsheet).find { |attributes| attributes[:whatsapp_at] }[:code] }

  context 'when a record already has the whatsapp_at stamped by a previous import' do
    let!(:record) { create(:atua_customer, tenant:, code:, whatsapp_at: Time.zone.local(2026, 9, 1, 8)) }

    it 'keeps the stamped date' do
      result = described_class.call(import, spreadsheet)

      expect(result.updated).to eq(1)
      expect(record.reload.whatsapp_at).to eq(Time.zone.local(2026, 9, 1, 8))
      expect(record.import).to eq(import)
    end
  end

  it 'is the save command of the customers report' do
    expect(Atua::SaveReportCommand.for(:customers)).to eq(described_class)
  end
end
