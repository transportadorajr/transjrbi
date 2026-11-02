require 'rails_helper'

RSpec.describe Atua::ApplyVehicleSaleCommand do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }
  let(:own_sender) { { document_kind: 'ce', sender_name: 'TRANSJR TRANSPORTADORA LTDA', sender_document_digits: '10212838000100' } }

  context 'with documents sent by the company itself' do
    let!(:vehicle_sale) { create(:atua_transport_document, tenant:, **own_sender, freight_cents: 71_818_500, goods_value_cents: 71_818_500) }
    let!(:sale_expense) { create(:freight_expense, tenant:, transport_document: vehicle_sale) }
    let!(:internal_shipment) { create(:atua_transport_document, tenant:, **own_sender, freight_cents: 900_000, goods_value_cents: 100_000) }
    let!(:shipment_expense) { create(:freight_expense, tenant:, transport_document: internal_shipment) }
    let!(:cte) { create(:atua_transport_document, tenant:, **own_sender, document_kind: 'cte', freight_cents: 100, goods_value_cents: 100) }
    let!(:other_sender) do
      create(:atua_transport_document, tenant:, document_kind: 'ce', sender_document_digits: '12261462006697', freight_cents: 45_000_000, goods_value_cents: 45_000_000)
    end
    let!(:stranger) { create(:atua_transport_document, tenant: other_tenant, **own_sender, freight_cents: 29_000_000, goods_value_cents: 29_000_000) }

    it 'marks only the vehicle sales of the tenant and removes their freight expenses' do
      expect { expect(described_class.call(tenant)).to eq(1) }.to change(FreightExpense, :count).by(-1)

      expect(vehicle_sale.reload.vehicle_sale).to be(true)
      expect(internal_shipment.reload.vehicle_sale).to be(false)
      expect(cte.reload.vehicle_sale).to be(false)
      expect(other_sender.reload.vehicle_sale).to be(false)
      expect(stranger.reload.vehicle_sale).to be(false)
      expect(FreightExpense.where(transport_document: vehicle_sale)).to be_empty
      expect(FreightExpense.where(transport_document: internal_shipment)).to contain_exactly(shipment_expense)
    end

    it 'can run again without changing the documents' do
      described_class.call(tenant)

      expect(described_class.call(tenant)).to eq(0)
      expect(vehicle_sale.reload.vehicle_sale).to be(true)
    end
  end
end
