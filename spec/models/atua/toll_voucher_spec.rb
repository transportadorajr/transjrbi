require 'rails_helper'

RSpec.describe Atua::TollVoucher do
  let(:tenant) { create(:tenant) }

  describe 'validations' do
    it 'requires a code unique per tenant' do
      create(:atua_toll_voucher, tenant:, code: '2:1:1')

      expect(build(:atua_toll_voucher, tenant:, code: '2:1:1')).not_to be_valid
      expect(build(:atua_toll_voucher, code: '2:1:1')).to be_valid
    end
  end

  describe '.by_period' do
    let!(:inside) { create(:atua_toll_voucher, tenant:, issued_on: Date.new(2026, 10, 24)) }
    let!(:outside) { create(:atua_toll_voucher, tenant:, issued_on: Date.new(2026, 9, 24)) }

    it 'filters by the issue of the transport document' do
      expect(described_class.count).to eq(2)
      expect(described_class.by_period('2026-10-01', '2026-10-31')).to eq([inside])
    end
  end

  describe '#transport_document' do
    let!(:document) { create(:atua_transport_document, tenant:, number: '74855', branch_code: 2, toll_cents: 0) }
    let!(:voucher) { create(:atua_toll_voucher, tenant:, transport_document_number: '74855', branch_code: 2, toll_cents: 58_517) }
    let!(:canceled) { create(:atua_toll_voucher, tenant:, transport_document_number: '74855', branch_code: 2, toll_cents: 1_000, canceled_on: Date.new(2026, 10, 25)) }
    let!(:other_branch) { create(:atua_toll_voucher, tenant:, transport_document_number: '74855', branch_code: 3, toll_cents: 2_000) }

    it 'links the voucher and sums only the valid tolls paid' do
      expect(voucher.transport_document).to eq(document)
      expect(document.toll_voucher_paid).to eq(Money.from_cents(58_517))
    end
  end
end
