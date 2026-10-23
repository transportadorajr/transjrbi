require 'rails_helper'

RSpec.describe FreightExpenses::CalculateFuelCommand do
  let(:tenant) { create(:tenant) }

  context 'without groups with fuel' do
    before do
      create(:truck_group, tenant:, fuel_percentage: 0)
      create(:truck_group, :ls, tenant:, activated_at: nil)
      create(:atua_transport_document, tenant:, axles: 9, freight_cents: 1_000_000)
      create(:atua_transport_document, tenant:, axles: 6, freight_cents: 1_000_000)
    end

    it 'does not record the fuel' do
      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 0))
      expect(FreightExpense.count).to eq(0)
    end
  end

  context 'with groups with fuel' do
    let!(:rodotrem) { create(:truck_group, tenant:, axles: [9], fuel_percentage: BigDecimal('35')) }
    let!(:ls) { create(:truck_group, :ls, tenant:, axles: [6, 5], fuel_percentage: BigDecimal('32.5')) }
    let!(:steel) { create(:atua_transport_document, tenant:, number: '78001', axles: 9, freight_cents: 1_000_000) }
    let!(:coil) { create(:atua_transport_document, tenant:, number: '78002', axles: 5, freight_cents: 400_001) }

    before do
      create(:atua_transport_document, tenant:, number: '78003', axles: 7, freight_cents: 500_000)
      create(:atua_transport_document, tenant:, number: '78004', axles: nil, freight_cents: 500_000)
      create(:atua_transport_document, tenant:, number: '78005', axles: 9, freight_cents: 0)
      create(:atua_transport_document, tenant:, number: '78006', axles: 9, document_kind: 'ce')
      create(:atua_transport_document, tenant:, number: '78007', axles: 9, issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT)
      create(:atua_transport_document, tenant:, number: '78008', axles: 9, canceled_at: Time.current)
      create(:atua_transport_document, tenant: create(:tenant), number: '78009', axles: 9, freight_cents: 1_000_000)
    end

    it 'records the fuel percentage of the group of the axle count over the freight of each transport document' do
      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 2, removed: 0))

      expect(FreightExpense.count).to eq(2)
      expect(FreightExpense.order(:transport_document_id).map do |expense|
        [expense.transport_document.number, expense.truck_group, expense.base_cents, expense.percentage, expense.amount_cents]
      end).to eq([['78001', rodotrem, 1_000_000, BigDecimal('35'), 350_000], ['78002', ls, 400_001, BigDecimal('32.5'), 130_000]])
      expect(FreightExpense.all).to all(have_attributes(tenant:, kind_type: 'fuel', calculated_at: be_present))
    end

    it 'can run again without changing the fuel' do
      described_class.call(tenant)

      expect { expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 0)) }
        .not_to(change { FreightExpense.order(:id).pluck(:id, :amount_cents, :updated_at) })
    end

    it 'keeps the other expenses of the same transport document' do
      commission = create(:freight_expense, tenant:, transport_document: steel)

      described_class.call(tenant)

      expect(commission.reload).to be_commission
      expect(steel.freight_expenses.pluck(:kind_type)).to contain_exactly('commission', 'fuel')
    end

    it 'recalculates every transport document of the group when its percentage changes' do
      described_class.call(tenant)
      rodotrem.update!(fuel_percentage: BigDecimal('40'))

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 1, removed: 0))
      expect(FreightExpense.find_by!(transport_document: steel)).to have_attributes(percentage: BigDecimal('40'), amount_cents: 400_000)
    end

    it 'removes the fuel of a transport document canceled afterwards' do
      described_class.call(tenant)
      coil.update!(canceled_at: Time.current)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 1))
      expect(FreightExpense.exists?(transport_document: coil)).to be(false)
    end

    it 'removes the fuel of a group deactivated afterwards' do
      described_class.call(tenant)
      ls.update!(activated_at: nil)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 1))
      expect(FreightExpense.pluck(:transport_document_id)).to eq([steel.id])
    end
  end

  context 'with a group of the remaining axles' do
    let!(:others) { create(:truck_group, :others, tenant:) }
    let!(:rodotrem) { create(:truck_group, tenant:, axles: [9], fuel_percentage: BigDecimal('29')) }
    let!(:truck) { create(:atua_transport_document, tenant:, number: '79001', axles: 4, freight_cents: 1_000_000) }
    let!(:without_axles) { create(:atua_transport_document, tenant:, number: '79002', axles: nil, freight_cents: 200_000) }
    let!(:steel) { create(:atua_transport_document, tenant:, number: '79003', axles: 9, freight_cents: 1_000_000) }

    before do
      create(:truck_group, :ls, tenant:, fuel_percentage: 0)
      create(:atua_transport_document, tenant:, number: '79004', axles: 6, freight_cents: 1_000_000)
      create(:atua_transport_document, tenant:, number: '79005', axles: 3, document_kind: 'ce')
      create(:atua_transport_document, tenant: create(:tenant), number: '79006', axles: 4, freight_cents: 1_000_000)
    end

    it 'records the fuel of the axle counts out of the other active groups over the gross freight' do
      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 3, removed: 0))

      expect(FreightExpense.count).to eq(3)
      expect(FreightExpense.order(:transport_document_id).map do |expense|
        [expense.transport_document.number, expense.truck_group, expense.base_cents, expense.percentage, expense.amount_cents]
      end).to eq(
        [
          ['79001', others, 1_000_000, BigDecimal('33'), 330_000],
          ['79002', others, 200_000, BigDecimal('33'), 66_000],
          ['79003', rodotrem, 1_000_000, BigDecimal('29'), 290_000],
        ],
      )
    end

    it 'moves the axle count to the remaining axles group when its group is deactivated' do
      described_class.call(tenant)
      rodotrem.update!(activated_at: nil)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 1, removed: 0))
      expect(FreightExpense.find_by!(transport_document: steel)).to have_attributes(truck_group: others, amount_cents: 330_000)
    end

    it 'removes the fuel of the remaining axles when the group is deactivated' do
      described_class.call(tenant)
      others.update!(activated_at: nil)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 2))
      expect(FreightExpense.pluck(:transport_document_id)).to eq([steel.id])
    end
  end
end
