require 'rails_helper'

RSpec.describe FreightExpenses::CalculateTonnageCommand do
  let(:tenant) { create(:tenant) }
  let(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS', terms: ['USIMINAS']) }
  let!(:usiminas_customer) { create(:atua_customer, tenant:, code: 501, name: 'USIMINAS CUBATAO', customer_group: usiminas) }
  let!(:cubatao) { create(:tonnage_rate, tenant:, customer_group: usiminas, valid_month: Date.new(2026, 10, 1), rate_cents: 1_257) }
  let!(:ipatinga) do
    create(:tonnage_rate, tenant:, customer_group: usiminas, nickname: nil, origin_city: 'Ipatinga', origin_state: 'MG',
                          valid_month: Date.new(2026, 10, 1), rate_cents: 860)
  end

  context 'with transport documents of the Usiminas group' do
    let!(:from_cubatao) do
      create(:atua_transport_document, tenant:, number: '75001', taker_code: 501, origin_city: 'CUBATÃO', origin_state: 'SP',
                                       issued_at: Time.zone.local(2026, 10, 5, 8), weight_tons: BigDecimal('32.5'))
    end
    let!(:from_ipatinga_in_kg) do
      create(:atua_transport_document, tenant:, number: '75002', taker_code: 501, origin_city: 'Ipatinga', origin_state: 'mg',
                                       issued_at: Time.zone.local(2026, 10, 6, 8), weight_tons: BigDecimal('27150'))
    end
    let!(:ce) do
      create(:atua_transport_document, tenant:, number: '75003', taker_code: 501, document_kind: 'ce', origin_city: 'CUBATAO',
                                       origin_state: 'SP', issued_at: Time.zone.local(2026, 10, 7, 8), weight_tons: 10)
    end
    let!(:without_weight) do
      create(:atua_transport_document, tenant:, number: '75004', taker_code: 501, origin_city: 'CUBATAO', origin_state: 'SP',
                                       issued_at: Time.zone.local(2026, 10, 8, 8), weight_tons: nil, weight_kg: nil)
    end
    let!(:other_origin) do
      create(:atua_transport_document, tenant:, number: '75005', taker_code: 501, origin_city: 'BETIM', origin_state: 'MG',
                                       issued_at: Time.zone.local(2026, 10, 9, 8), weight_tons: 20)
    end

    it 'records the tonnage cost of each transport document with the rate of its origin' do
      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 3, removed: 0))

      expect(FreightExpense.count).to eq(3)
      expect(FreightExpense.order(:transport_document_id).map { |expense| expense_values(expense) }).to eq(
        [
          ['75001', cubatao, BigDecimal('32.5'), 1_257, 40_853],
          ['75002', ipatinga, BigDecimal('27.15'), 860, 23_349],
          ['75003', cubatao, BigDecimal('10'), 1_257, 12_570],
        ],
      )
      expect(FreightExpense.all).to all(have_attributes(tenant:, kind_type: 'tonnage', commission_rule: nil, calculated_at: be_present))
    end

    it 'can run again without changing the costs' do
      described_class.call(tenant)

      expect { expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 0)) }
        .not_to(change { FreightExpense.order(:id).pluck(:id, :amount_cents, :updated_at) })
    end

    it 'keeps the commission of the same transport document' do
      commission = create(:freight_expense, tenant:, transport_document: from_cubatao)

      described_class.call(tenant)

      expect(commission.reload).to be_commission
      expect(from_cubatao.freight_expenses.pluck(:kind_type)).to contain_exactly('commission', 'tonnage')
    end

    it 'recalculates the costs when the rate is corrected' do
      described_class.call(tenant)
      cubatao.update!(rate_cents: 1_300)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 2, removed: 0))
      expect(FreightExpense.find_by!(transport_document: from_cubatao)).to have_attributes(rate_cents: 1_300, amount_cents: 42_250)
    end

    it 'removes the costs when the rate is deactivated' do
      described_class.call(tenant)
      ipatinga.update!(activated_at: nil)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 1))
      expect(FreightExpense.exists?(transport_document: from_ipatinga_in_kg)).to be(false)
    end

    it 'removes the cost of a transport document canceled after the calculation' do
      described_class.call(tenant)
      from_cubatao.update!(canceled_at: Time.current)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 1))
      expect(FreightExpense.exists?(transport_document: from_cubatao)).to be(false)
    end
  end

  context 'with transport documents of months with and without their own rate' do
    let!(:september_document) do
      create(:atua_transport_document, tenant:, number: '75101', taker_code: 501, origin_city: 'CUBATAO', origin_state: 'SP',
                                       issued_at: Time.zone.local(2026, 9, 20, 8), weight_tons: 10)
    end
    let!(:november_document) do
      create(:atua_transport_document, tenant:, number: '75102', taker_code: 501, origin_city: 'CUBATAO', origin_state: 'SP',
                                       issued_at: Time.zone.local(2026, 11, 2, 8), weight_tons: 10)
    end

    it 'uses the first rate before it and the previous month while the month has no rate' do
      described_class.call(tenant)

      expect(FreightExpense.find_by!(transport_document: september_document)).to have_attributes(tonnage_rate: cubatao, amount_cents: 12_570)
      expect(FreightExpense.find_by!(transport_document: november_document)).to have_attributes(tonnage_rate: cubatao, amount_cents: 12_570)
    end

    it 'recalculates the transport documents of the month once its rate is registered' do
      described_class.call(tenant)
      november = create(:tonnage_rate, tenant:, customer_group: usiminas, valid_month: Date.new(2026, 11, 1), rate_cents: 1_400)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 1, removed: 0))
      expect(FreightExpense.find_by!(transport_document: november_document)).to have_attributes(tonnage_rate: november, amount_cents: 14_000)
      expect(FreightExpense.find_by!(transport_document: september_document)).to have_attributes(tonnage_rate: cubatao)
    end
  end

  context 'with a transport document whose taker is not in the group' do
    let!(:sender_only) do
      create(:atua_transport_document, tenant:, sender_code: 501, taker_code: 999, origin_city: 'CUBATAO', origin_state: 'SP',
                                       issued_at: Time.zone.local(2026, 10, 5, 8), weight_tons: 10)
    end

    it 'does not record the cost' do
      described_class.call(tenant)

      expect(FreightExpense.count).to eq(0)
    end
  end

  context 'with a rate of another tenant' do
    let(:other_tenant) { create(:tenant) }
    let(:stranger_group) { create(:customer_group, tenant: other_tenant, name: 'USIMINAS') }
    let!(:stranger_customer) { create(:atua_customer, tenant: other_tenant, code: 501, customer_group: stranger_group) }
    let!(:stranger_rate) { create(:tonnage_rate, tenant: other_tenant, customer_group: stranger_group) }
    let!(:stranger_document) do
      create(:atua_transport_document, tenant: other_tenant, taker_code: 501, origin_city: 'CUBATAO', origin_state: 'SP',
                                       issued_at: Time.zone.local(2026, 10, 5, 8), weight_tons: 10)
    end

    it 'calculates only the costs of the given tenant' do
      described_class.call(tenant)

      expect(FreightExpense.count).to eq(0)
    end
  end

  def expense_values(expense)
    [expense.transport_document.number, expense.tonnage_rate, expense.weight_tons, expense.rate_cents, expense.amount_cents]
  end
end
