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

    it 'recalculates the transport documents issued from the month the new percentage is valid' do
      described_class.call(tenant)
      rodotrem.change_fuel_percentage(BigDecimal('40'), steel.issued_at.to_date.beginning_of_month)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 1, removed: 0))
      expect(FreightExpense.find_by!(transport_document: steel)).to have_attributes(percentage: BigDecimal('40'), amount_cents: 400_000)
    end

    it 'keeps the percentage of the transport documents issued before the new percentage is valid' do
      described_class.call(tenant)
      rodotrem.change_fuel_percentage(BigDecimal('40'), steel.issued_at.to_date.next_month.beginning_of_month)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 0))
      expect(FreightExpense.find_by!(transport_document: steel)).to have_attributes(percentage: BigDecimal('35'), amount_cents: 350_000)
    end

    it 'applies each percentage to the month of issue of the transport document' do
      september = create(:atua_transport_document, tenant:, axles: 9, freight_cents: 1_000_000, issued_at: Time.zone.local(2026, 9, 30, 23))
      rodotrem.fuel_rates.delete_all
      rodotrem.fuel_rates.create!(valid_month: Date.new(2026, 9, 1), percentage: BigDecimal('30'))
      rodotrem.fuel_rates.create!(valid_month: Date.new(2026, 10, 1), percentage: BigDecimal('35'))

      described_class.call(tenant)

      expect(FreightExpense.find_by!(transport_document: september).percentage).to eq(BigDecimal('30'))
      expect(FreightExpense.find_by!(transport_document: steel).percentage).to eq(BigDecimal('35'))
    end

    it 'uses the current percentage for a transport document without an issue date' do
      undated = create(:atua_transport_document, tenant:, axles: 9, freight_cents: 1_000_000, issued_at: nil)

      described_class.call(tenant)

      expect(FreightExpense.find_by!(transport_document: undated).percentage).to eq(BigDecimal('35'))
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

  context 'with a group of plates' do
    let!(:ls) { create(:truck_group, :ls, tenant:, fuel_percentage: BigDecimal('33')) }
    let!(:utinga) { create(:truck_group, :utinga, tenant:) }
    let!(:listed) { create(:atua_transport_document, tenant:, number: '80001', plate: 'BAV5A04', axles: 6, freight_cents: 1_000_000) }
    let!(:five_axles) { create(:atua_transport_document, tenant:, number: '80002', plate: 'EVO8C24', axles: 5, freight_cents: 1_000_000) }
    let!(:other_truck) { create(:atua_transport_document, tenant:, number: '80003', plate: 'RVR2C34', axles: 6, freight_cents: 1_000_000) }

    before { create(:atua_transport_document, tenant:, number: '80004', plate: 'RVR2C34', axles: 5, freight_cents: 1_000_000) }

    it 'prefers the plate over the axle count and leaves out the documents of no group' do
      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 3, removed: 0))

      expect(FreightExpense.count).to eq(3)
      expect(FreightExpense.order(:transport_document_id).map { |expense| [expense.transport_document, expense.truck_group, expense.amount_cents] })
        .to eq([[listed, utinga, 280_000], [five_axles, utinga, 280_000], [other_truck, ls, 330_000]])
    end

    it 'moves the documents back to the axle count group when the plate group is deactivated' do
      described_class.call(tenant)
      utinga.update!(activated_at: nil)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 1, removed: 1))
      expect(FreightExpense.find_by!(transport_document: listed)).to have_attributes(truck_group: ls, amount_cents: 330_000)
      expect(FreightExpense.exists?(transport_document: five_axles)).to be(false)
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
