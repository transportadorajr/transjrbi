require 'rails_helper'

RSpec.describe Dashboard::AdvanceIcms do
  subject(:dashboard) { described_class.new(tenant.atua_transport_documents.advance_icms, tenant.atua_transport_documents.active.not_canceled.freights) }

  let!(:tenant) { create(:tenant) }
  let!(:gerdau) { create(:customer_group, tenant:, name: 'GERDAU', pays_advance_icms_at: Time.current) }
  let!(:arcelor) { create(:customer_group, tenant:, name: 'ARCELOR') }
  let!(:gerdau_customer) { create(:atua_customer, tenant:, code: 601, customer_group: gerdau) }
  let!(:arcelor_customer) { create(:atua_customer, tenant:, code: 602, customer_group: arcelor) }
  let!(:october_paid) do
    create(:atua_transport_document, tenant:, number: '75001', taker_code: 601, cfop: 6932, issued_at: Time.zone.local(2026, 10, 20, 8),
                                     freight_cents: 100_000, icms_cents: 12_000)
  end
  let!(:november_pending) do
    create(:atua_transport_document, tenant:, number: '75002', taker_code: 601, cfop: 6932, issued_at: Time.zone.local(2026, 11, 2, 8),
                                     freight_cents: 50_000, icms_cents: 6_000)
  end
  let!(:november_paid) do
    create(:atua_transport_document, tenant:, number: '75003', taker_code: 602, cfop: 6932, issued_at: Time.zone.local(2026, 11, 20, 8),
                                     freight_cents: 200_000, icms_cents: 24_000)
  end
  let!(:without_group) do
    create(:atua_transport_document, tenant:, number: '75004', taker_code: 999, cfop: 6932, issued_at: Time.zone.local(2026, 11, 21, 8),
                                     freight_cents: 10_000, icms_cents: 1_200)
  end

  before do
    create(:atua_transport_document, tenant:, number: '75005', taker_code: 602, cfop: 6353, issued_at: Time.zone.local(2026, 11, 22, 8),
                                     freight_cents: 300_000, icms_cents: 36_000)
    create(:atua_expense, tenant:, history_code: 503, history_name: 'ICMS ANTECIPADO', cost_object: october_paid, total_cents: 12_000)
    create(:atua_expense, tenant:, history_code: 503, history_name: 'ICMS ANTECIPADO', cost_object: november_paid, total_cents: 24_000)
    other_tenant = create(:tenant)
    create(:atua_transport_document, tenant: other_tenant, number: '75006', cfop: 6932, issued_at: Time.zone.local(2026, 11, 2, 8), icms_cents: 9_000)
  end

  it 'sums the posted guides and the ICMS of the pending guides by month of issue' do
    expect(dashboard.monthly_data).to eq(
      [{ name: 'Guias lançadas', data: { 'Out/2026' => BigDecimal('120'), 'Nov/2026' => BigDecimal('240') } },
       { name: 'ICMS com guia pendente', data: { 'Out/2026' => BigDecimal('0'), 'Nov/2026' => BigDecimal('60') } }],
    )
  end

  it 'totals the guides of each customer group against the gross billing of the group' do
    rows = dashboard.group_rows.map { |row| [row.label, row.count, row.icms.cents, row.guide.cents, row.pending.cents, row.gross.cents, row.share] }

    expect(rows).to eq(
      [
        ['ARCELOR', 1, 24_000, 24_000, 0, 500_000, BigDecimal('4.8')],
        ['GERDAU', 2, 18_000, 12_000, 6_000, 150_000, BigDecimal('8')],
        ['Sem grupo', 1, 1_200, 0, 0, 10_000, BigDecimal('0')],
      ],
    )
  end

  it 'counts the pending guides of CT-es issued more than 5 days ago' do
    travel_to Time.zone.local(2026, 11, 6, 8) do
      expect(dashboard.overdue_count).to eq(0)
    end

    travel_to Time.zone.local(2026, 11, 8, 8) do
      expect(described_class.new(tenant.atua_transport_documents.advance_icms, tenant.atua_transport_documents).overdue_count).to eq(1)
    end
  end

  context 'without CT-es' do
    subject(:dashboard) { described_class.new(tenant.atua_transport_documents.none.advance_icms, tenant.atua_transport_documents.none) }

    it 'has no month and no group' do
      expect(dashboard.monthly?).to be(false)
      expect(dashboard.group_rows).to eq([])
    end
  end
end
