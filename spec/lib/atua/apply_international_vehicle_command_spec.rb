require 'rails_helper'

RSpec.describe Atua::ApplyInternationalVehicleCommand do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }
  let(:billing_border) { { destination_city: 'FOZ DO IGUACU', destination_state: 'PR' } }
  let(:truck_vehicle) { { plate: 'BDZ8J90', trailer_plate: 'AQZ1D12', vehicle_code: 585 } }

  context 'with Arcelor CEs issued on the truck plates' do
    let!(:international_vehicle) { create(:atua_vehicle, tenant:, plate: 'INT6R00', code: 824) }
    let!(:billing_only) do
      create(:atua_transport_document, tenant:, document_kind: 'ce', taker_name: 'ARCELORMITTAL BRASIL S.A.', **billing_border, **truck_vehicle)
    end
    let!(:international_plate) do
      create(:atua_transport_document, tenant:, document_kind: 'ce', taker_name: 'OUTRO', **billing_border, plate: 'INT6R00', trailer_plate: nil, vehicle_code: 824)
    end
    let!(:real_trip) do
      create(:atua_transport_document, tenant:, document_kind: 'cte', taker_name: 'ARCELORMITTAL BRASIL S.A.', **billing_border, **truck_vehicle)
    end
    let!(:other_customer) { create(:atua_transport_document, tenant:, document_kind: 'ce', taker_name: 'USIMINAS', **billing_border, **truck_vehicle) }
    let!(:other_destination) do
      create(:atua_transport_document, tenant:, document_kind: 'ce', taker_name: 'ARCELORMITTAL BRASIL S.A.', destination_city: 'TRES LAGOAS',
                                       destination_state: 'MS', **truck_vehicle)
    end
    let!(:stranger) do
      create(:atua_transport_document, tenant: other_tenant, document_kind: 'ce', taker_name: 'ARCELORMITTAL BRASIL S.A.', **billing_border, **truck_vehicle)
    end

    it 'moves only the Arcelor CEs bound for Foz do Iguacu of the tenant to the international vehicle' do
      expect(described_class.call(tenant)).to eq(1)

      expect(billing_only.reload).to have_attributes(plate: 'INT6R00', trailer_plate: nil, vehicle_code: 824)
      expect(international_plate.reload).to have_attributes(plate: 'INT6R00', trailer_plate: nil, vehicle_code: 824)
      expect(real_trip.reload).to have_attributes(truck_vehicle)
      expect(other_customer.reload).to have_attributes(truck_vehicle)
      expect(other_destination.reload).to have_attributes(truck_vehicle)
      expect(stranger.reload).to have_attributes(truck_vehicle)
    end

    it 'can run again without changing the documents' do
      described_class.call(tenant)

      expect(described_class.call(tenant)).to eq(0)
      expect(billing_only.reload.plate).to eq('INT6R00')
    end
  end

  context 'when the international vehicle is not registered' do
    let!(:billing_only) do
      create(:atua_transport_document, tenant:, document_kind: 'ce', taker_name: 'ARCELORMITTAL BRASIL S.A.', **billing_border, **truck_vehicle)
    end

    it 'moves the CE to the international plate and keeps its vehicle code' do
      expect(described_class.call(tenant)).to eq(1)

      expect(billing_only.reload).to have_attributes(plate: 'INT6R00', trailer_plate: nil, vehicle_code: 585)
    end
  end
end
