require 'rails_helper'

RSpec.describe FreightExpense do
  let(:tenant) { create(:tenant) }

  describe 'validations' do
    it 'requires the rule of a commission' do
      expense = build(:freight_expense, tenant:, commission_rule: nil)

      expect(expense).not_to be_valid
      expect(expense.errors[:commission_rule]).to eq(['não pode ficar em branco'])
    end

    it 'accepts a single commission per transport document' do
      existing = create(:freight_expense, tenant:)
      duplicated = build(:freight_expense, tenant:, transport_document: existing.transport_document)

      expect(duplicated).not_to be_valid
      expect(duplicated.errors[:kind_type]).to eq(['já está em uso'])
    end
  end

  describe 'scopes' do
    let(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
    let(:arcelor) { create(:customer_group, tenant:, name: 'ARCELORMITTAL') }
    let(:usiminas_rule) { create(:commission_rule, tenant:, customer_group: usiminas) }
    let(:arcelor_rule) { create(:commission_rule, tenant:, customer_group: arcelor) }
    let(:september) { create(:atua_transport_document, tenant:, number: '74001', issued_at: Time.zone.local(2026, 9, 30, 10)) }
    let(:october) { create(:atua_transport_document, tenant:, number: '74002', issued_at: Time.zone.local(2026, 10, 1, 10)) }
    let!(:september_expense) { create(:freight_expense, tenant:, commission_rule: usiminas_rule, transport_document: september) }
    let!(:october_expense) { create(:freight_expense, tenant:, commission_rule: arcelor_rule, transport_document: october) }

    it 'filters by the issue date of the transport document' do
      expect(described_class.by_period_start('2026-10-01')).to contain_exactly(october_expense)
      expect(described_class.by_period_end('2026-09-30')).to contain_exactly(september_expense)
    end

    it 'filters by the transport document number and by the customer group of the rule' do
      expect(described_class.by_transport_document_number(' 74001 ')).to contain_exactly(september_expense)
      expect(described_class.by_customer_group(arcelor.id)).to contain_exactly(october_expense)
    end
  end
end
