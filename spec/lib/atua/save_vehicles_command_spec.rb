require 'rails_helper'

RSpec.describe Atua::SaveVehiclesCommand do
  let(:tenant) { create(:tenant) }
  let(:import) { create(:atua_import, tenant:, report_type: 'vehicles', status_type: 'running', start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 13)) }
  let(:spreadsheet) { read_atua_fixture(:vehicles) }
  let(:code) { Atua::MapVehiclesCommand.call(tenant, spreadsheet).find { |attributes| attributes[:owner_whatsapp_at] }[:code] }

  context 'when a record already has the owner_whatsapp_at stamped by a previous import' do
    let!(:record) { create(:atua_vehicle, tenant:, code:, owner_whatsapp_at: Time.zone.local(2026, 9, 1, 8)) }

    it 'keeps the stamped date' do
      result = described_class.call(import, spreadsheet)

      expect(result.updated).to eq(1)
      expect(record.reload.owner_whatsapp_at).to eq(Time.zone.local(2026, 9, 1, 8))
      expect(record.import).to eq(import)
    end
  end

  it 'is the save command of the vehicles report' do
    expect(Atua::SaveReportCommand.for(:vehicles)).to eq(described_class)
  end
end
