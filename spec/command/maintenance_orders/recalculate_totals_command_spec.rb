require 'rails_helper'

RSpec.describe MaintenanceOrders::RecalculateTotalsCommand do
  let(:tenant) { create(:tenant) }
  let!(:maintenance_order) { create(:maintenance_order, tenant:, total_cents: 99_999) }
  let!(:other_order) { create(:maintenance_order, tenant:) }

  context 'without items' do
    it 'zeroes the totals' do
      described_class.call(maintenance_order)

      expect(maintenance_order.reload).to have_attributes(parts_total_cents: 0, services_total_cents: 0, total_cents: 0)
    end
  end

  context 'with parts and services' do
    let!(:pads) { create(:maintenance_order_part, maintenance_order:, total_cents: 34_000) }
    let!(:oil) { create(:maintenance_order_part, maintenance_order:, total_cents: 12_550) }
    let!(:approved_service) { create(:maintenance_order_service, maintenance_order:, quoted_cents: 45_000, approved_cents: 42_000) }
    let!(:quoted_service) { create(:maintenance_order_service, maintenance_order:, quoted_cents: 8_000, approved_cents: nil) }
    let!(:service_without_value) { create(:maintenance_order_service, maintenance_order:, quoted_cents: nil) }
    let!(:other_part) { create(:maintenance_order_part, maintenance_order: other_order, total_cents: 1_000) }

    it 'sums the parts and the approved value of the services, falling back to the quoted value' do
      described_class.call(maintenance_order)

      expect(maintenance_order.reload).to have_attributes(parts_total_cents: 46_550, services_total_cents: 50_000,
                                                          total_cents: 96_550)
    end

    it 'gives the same totals when called again' do
      2.times { described_class.call(maintenance_order) }

      expect(maintenance_order.reload.total_cents).to eq(96_550)
      expect(other_order.reload.total_cents).to eq(0)
    end
  end
end
