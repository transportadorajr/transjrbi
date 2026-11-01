require 'rails_helper'

RSpec.describe FreightExpenses::CalculateInsuranceCommand do
  let(:tenant) { create(:tenant) }

  context 'without an insurance rate' do
    before { create(:atua_transport_document, tenant:, goods_value_cents: 838_998) }

    it 'does not record the insurance' do
      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 0))
      expect(FreightExpense.count).to eq(0)
    end
  end

  context 'with an insurance rate' do
    let!(:rate) { create(:insurance_rate, tenant:) }
    let!(:national) do
      create(:atua_transport_document, tenant:, number: '76001', goods_value_cents: 838_998, freight_cents: 55_504, destination_state: 'MG',
                                       issued_at: Time.zone.local(2026, 10, 5, 8))
    end
    let!(:international) do
      create(:atua_transport_document, tenant:, number: '76002', goods_value_cents: 838_998, freight_cents: 55_504, destination_state: 'ex',
                                       issued_at: Time.zone.local(2026, 10, 6, 8))
    end

    before do
      link_to_manifest(national)
      link_to_manifest(international)
      link_to_manifest(create(:atua_transport_document, tenant:, number: '76003', document_kind: 'ce', goods_value_cents: 100_000))
      link_to_manifest(create(:atua_transport_document, tenant:, number: '76004', issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT,
                                                        goods_value_cents: 100_000))
      link_to_manifest(create(:atua_transport_document, tenant:, number: '76005', canceled_at: Time.current, goods_value_cents: 100_000))
      link_to_manifest(create(:atua_transport_document, tenant: create(:tenant), number: '76006', goods_value_cents: 100_000))
    end

    it 'records the insurance over the goods value only, adding the IOF on the international ones' do
      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 2, removed: 0))

      expect(FreightExpense.count).to eq(2)
      expect(FreightExpense.order(:transport_document_id).map { |expense| expense_values(expense) }).to eq(
        [
          ['76001', rate, 838_998, BigDecimal('0.022'), BigDecimal('0'), 0, 185],
          ['76002', rate, 838_998, BigDecimal('0.022'), BigDecimal('7.38'), 14, 199],
        ],
      )
      expect(FreightExpense.all).to all(have_attributes(tenant:, kind_type: 'insurance', commission_rule: nil, calculated_at: be_present))
    end

    it 'can run again without changing the insurance' do
      described_class.call(tenant)

      expect { expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 0)) }
        .not_to(change { FreightExpense.order(:id).pluck(:id, :amount_cents, :updated_at) })
    end

    it 'keeps the other expenses of the same transport document' do
      commission = create(:freight_expense, tenant:, transport_document: national)

      described_class.call(tenant)

      expect(commission.reload).to be_commission
      expect(national.freight_expenses.pluck(:kind_type)).to contain_exactly('commission', 'insurance')
    end

    it 'recalculates the insurance of every transport document when the rate is changed' do
      described_class.call(tenant)
      rate.update!(insurance_percentage: BigDecimal('0.03'))

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 2, removed: 0))
      expect(FreightExpense.find_by!(transport_document: national)).to have_attributes(percentage: BigDecimal('0.03'), amount_cents: 252)
      expect(FreightExpense.find_by!(transport_document: international)).to have_attributes(percentage: BigDecimal('0.03'), iof_cents: 19,
                                                                                            amount_cents: 271)
    end

    it 'removes the insurance of a transport document canceled afterwards' do
      described_class.call(tenant)
      international.update!(canceled_at: Time.current)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 1))
      expect(FreightExpense.exists?(transport_document: international)).to be(false)
    end

    context 'with a transport document without a manifest' do
      let!(:without_manifest) { create(:atua_transport_document, tenant:, number: '76007', goods_value_cents: 100_000) }

      it 'does not record the insurance' do
        expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 2, removed: 0))
        expect(FreightExpense.exists?(transport_document: without_manifest)).to be(false)
      end

      it 'records the insurance once the transport document is linked to a manifest' do
        described_class.call(tenant)
        link_to_manifest(without_manifest)

        expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 1, removed: 0))
        expect(FreightExpense.exists?(transport_document: without_manifest)).to be(true)
      end
    end

    context 'with a transport document linked only to a canceled manifest' do
      let!(:on_canceled_manifest) { create(:atua_transport_document, tenant:, number: '76008', goods_value_cents: 100_000) }

      before { link_to_manifest(on_canceled_manifest, status: Atua::Manifest::CANCELED_STATUS) }

      it 'does not record the insurance' do
        described_class.call(tenant)

        expect(FreightExpense.exists?(transport_document: on_canceled_manifest)).to be(false)
      end
    end

    context 'with a transport document linked to a manifest removed from Atua' do
      let!(:on_removed_manifest) { create(:atua_transport_document, tenant:, number: '76009', goods_value_cents: 100_000) }

      before { link_to_manifest(on_removed_manifest, removed_from_atua_at: Time.current) }

      it 'does not record the insurance' do
        described_class.call(tenant)

        expect(FreightExpense.exists?(transport_document: on_removed_manifest)).to be(false)
      end
    end

    it 'removes the insurance of a transport document whose manifest is canceled afterwards' do
      manifest = link_to_manifest(create(:atua_transport_document, tenant:, number: '76010', goods_value_cents: 100_000))
      described_class.call(tenant)
      manifest.update!(status: Atua::Manifest::CANCELED_STATUS)

      expect(described_class.call(tenant)).to eq(described_class::Result.new(saved: 0, removed: 1))
    end
  end

  def link_to_manifest(document, **manifest_attributes)
    manifest = create(:atua_manifest, tenant: document.tenant, **manifest_attributes)
    create(:atua_transport_document_manifest, tenant: document.tenant, transport_document_code: document.code,
                                              manifest_number: manifest.number, branch_name: manifest.branch_name)
    manifest
  end

  def expense_values(expense)
    [expense.transport_document.number, expense.insurance_rate, expense.base_cents, expense.percentage, expense.iof_percentage,
     expense.iof_cents, expense.amount_cents]
  end
end
