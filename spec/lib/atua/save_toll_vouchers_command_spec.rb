require 'rails_helper'

RSpec.describe Atua::SaveTollVouchersCommand do
  let(:tenant) { create(:tenant) }
  let(:import) { create(:atua_import, tenant:, report_type: 'toll_vouchers', status_type: 'running', start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 31)) }
  let(:row) do
    { 'nr_ctrc' => 74_855.0, 'dt_emissao' => '24/10/26', 'cd_pessoa_filial' => 2.0, 'vl_pedagio_ctrc' => 0.0, 'vl_pedagio' => 585.17, 'vl_total' => 585.17, 'nr_pedido' => '123' }
  end
  let(:spreadsheet) { Atua::ReadSpreadsheetCommand::Result.new(headers: row.keys, rows: [row]) }

  it 'is the save command of the toll vouchers report' do
    expect(Atua::SaveReportCommand.for(:toll_vouchers)).to eq(described_class)
  end

  it 'reads the real layout of the report' do
    result = described_class.call(import, read_atua_fixture(:toll_vouchers))

    expect(result).to have_attributes(inserted: 3, updated: 0)
    expect(Atua::TollVoucher.find_by!(transport_document_number: '74855')).to have_attributes(toll_cents: 58_517, charged_toll_cents: 0, issued_on: Date.new(2026, 10, 24))
  end

  it 'inserts the voucher and updates it on the next import' do
    expect(described_class.call(import, spreadsheet)).to have_attributes(inserted: 1, updated: 0, removed: 0)
    expect(described_class.call(import, spreadsheet)).to have_attributes(inserted: 0, updated: 1, removed: 0)
    expect(Atua::TollVoucher.sole).to have_attributes(tenant:, code: '2:74855:123', toll_cents: 58_517, import:)
  end

  context 'with a voucher of the period that left the report' do
    let!(:gone) { create(:atua_toll_voucher, tenant:, issued_on: Date.new(2026, 10, 2)) }
    let!(:out_of_period) { create(:atua_toll_voucher, tenant:, issued_on: Date.new(2026, 9, 2)) }

    it 'marks only that voucher as removed' do
      expect(described_class.call(import, spreadsheet)).to have_attributes(inserted: 1, removed: 1)
      expect(gone.reload.removed_from_atua_at).to be_present
      expect(out_of_period.reload.removed_from_atua_at).to be_nil
    end
  end
end
