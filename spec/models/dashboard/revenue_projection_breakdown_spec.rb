require 'rails_helper'

RSpec.describe Dashboard::RevenueProjectionBreakdown do
  subject(:breakdown) { described_class.new(freight, projected_cents:) }

  let!(:tenant) { create(:tenant) }
  let(:freight) do
    Dashboard::Freight.new(tenant.atua_transport_documents, manifests: tenant.atua_manifests, dimension:, period: Date.new(2026, 11, 1)..Date.new(2026, 11, 30))
  end
  let(:dimension) { 'vehicle' }
  let(:projected_cents) { 1_000_000 }

  context 'with freights of two vehicles' do
    before do
      create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 11, 2, 8), plate: 'BBB2B22', freight_cents: 300_000)
      create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 11, 3, 8), plate: 'AAA1A11', freight_cents: 100_000)
    end

    it 'shares the projection of the period by what each vehicle billed' do
      expect(breakdown).to be_projected
      expect(breakdown.dimension).to eq('vehicle')
      expect(breakdown.rows.map { [it.label, it.billed_cents, it.projected_cents, it.remaining_cents, it.share] }).to eq(
        [['BBB2B22', 300_000, 750_000, 450_000, BigDecimal('75')], ['AAA1A11', 100_000, 250_000, 150_000, BigDecimal('25')]],
      )
      expect(breakdown.total).to have_attributes(billed_cents: 400_000, projected_cents: 1_000_000, share: BigDecimal('100'))
    end

    it 'sorts by the label, the billed and the projection' do
      expect(breakdown.sorted_rows('label', 'asc').map(&:label)).to eq(%w[AAA1A11 BBB2B22])
      expect(breakdown.sorted_rows('billed', 'asc').map(&:label)).to eq(%w[AAA1A11 BBB2B22])
      expect(breakdown.sorted_rows('projected', 'desc').map(&:label)).to eq(%w[BBB2B22 AAA1A11])
      expect(breakdown.sorted_rows('plate', 'asc')).to eq(breakdown.rows)
    end

    context 'when the period is closed' do
      let(:projected_cents) { nil }

      it 'keeps the billed as the projection of each vehicle' do
        expect(breakdown).not_to be_projected
        expect(breakdown.rows.map { [it.label, it.projected_cents, it.remaining_cents] }).to eq([['BBB2B22', 300_000, 0], ['AAA1A11', 100_000, 0]])
      end
    end
  end

  context 'with freights of customer groups' do
    let(:dimension) { 'customer_group' }

    before do
      create(:atua_customer, tenant:, code: 7100, customer_group: create(:customer_group, tenant:, name: 'USIMINAS'))
      create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 11, 2, 8), taker_code: 7100, freight_cents: 200_000)
      create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 11, 2, 9), taker_code: 7100, freight_cents: 200_000)
    end

    it 'projects each customer group' do
      expect(breakdown.rows.map { [it.label, it.billed_cents, it.projected_cents] }).to eq([['USIMINAS', 400_000, 1_000_000]])
    end
  end

  context 'without freights in the period' do
    it 'has no rows' do
      expect(breakdown).not_to be_any
      expect(breakdown.total).to have_attributes(billed_cents: 0, projected_cents: 0)
    end
  end
end
