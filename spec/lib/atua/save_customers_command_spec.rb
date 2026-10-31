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

  context 'when the customers are saved' do
    let!(:customer_group) { create(:customer_group, tenant:, name: 'MANUAL') }
    let!(:record) { create(:atua_customer, tenant:, code:, customer_group:) }

    it 'links the new customers to a group and keeps the group of the existing ones' do
      described_class.call(import, spreadsheet)

      expect(tenant.atua_customers.count).to be > 1
      expect(tenant.atua_customers.without_customer_group.count).to eq(0)
      expect(record.reload.customer_group).to eq(customer_group)
    end
  end

  context 'when the report brings back a customer without recent transport documents' do
    before do
      create(:atua_transport_document, tenant:, taker_code: code, sender_code: nil, recipient_code: nil, payer_code: nil, consignee_code: nil, issued_at: 1.month.ago)
    end

    it 'keeps only the customer with a recent transport document' do
      described_class.call(import, spreadsheet)

      expect(tenant.atua_customers.pluck(:code)).to eq([code])
    end
  end

  it 'is the save command of the customers report' do
    expect(Atua::SaveReportCommand.for(:customers)).to eq(described_class)
  end
end
