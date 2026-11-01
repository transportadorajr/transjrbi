require 'rails_helper'

RSpec.describe Atua::ApplyRealOriginCommand do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }
  let(:billing_origin) { { origin_city: 'JUIZ DE FORA', origin_state: 'MG', origin_city_code: 1234, destination_city: 'FOZ DO IGUACU', destination_state: 'PR' } }

  context 'with documents billed to Foz do Iguacu' do
    let!(:west_parana) { create(:macro_region, tenant:, name: 'OESTE PARANA', state: 'PR', cities: ['Foz do Iguaçu']) }
    let!(:billing_only) { create(:atua_transport_document, tenant:, document_kind: 'ce', taker_name: 'ARCELORMITTAL BRASIL S.A.', **billing_origin) }
    let!(:real_trip) { create(:atua_transport_document, tenant:, document_kind: 'cte', taker_name: 'ARCELORMITTAL BRASIL S.A.', **billing_origin) }
    let!(:other_customer) { create(:atua_transport_document, tenant:, document_kind: 'ce', taker_name: 'USIMINAS', **billing_origin) }
    let!(:from_piracicaba) do
      create(:atua_transport_document, tenant:, document_kind: 'ce', taker_name: 'ARCELORMITTAL BRASIL S.A.', **billing_origin, origin_city: 'PIRACICABA', origin_state: 'SP')
    end
    let!(:international_plate) { create(:atua_transport_document, tenant:, document_kind: 'ce', taker_name: 'OUTRO', plate: 'INT6R00', **billing_origin, destination_city: 'CASCAVEL') }
    let!(:other_destination) { create(:atua_transport_document, tenant:, document_kind: 'ce', taker_name: 'ARCELORMITTAL BRASIL S.A.', **billing_origin, destination_city: 'TRES LAGOAS', destination_state: 'MS') }
    let!(:stranger) { create(:atua_transport_document, tenant: other_tenant, document_kind: 'ce', taker_name: 'ARCELORMITTAL BRASIL S.A.', **billing_origin) }

    it 'moves only the Arcelor CEs bound for Foz do Iguacu and the international plate CEs of the tenant and assigns their macro region' do
      expect(described_class.call(tenant)).to eq(3)

      expect(billing_only.reload).to have_attributes(
        origin_city: 'FOZ DO IGUACU', origin_state: 'PR', origin_city_code: 2946, origin_macro_region: west_parana,
      )
      expect(from_piracicaba.reload).to have_attributes(origin_city: 'FOZ DO IGUACU', origin_state: 'PR', origin_city_code: 2946)
      expect(international_plate.reload).to have_attributes(origin_city: 'FOZ DO IGUACU', origin_state: 'PR', origin_city_code: 2946)
      expect(other_destination.reload.origin_city).to eq('JUIZ DE FORA')
      expect(real_trip.reload).to have_attributes(billing_origin)
      expect(other_customer.reload).to have_attributes(billing_origin)
      expect(stranger.reload).to have_attributes(billing_origin)
    end

    it 'can run again without changing the documents' do
      described_class.call(tenant)

      expect(described_class.call(tenant)).to eq(0)
      expect(billing_only.reload.origin_city).to eq('FOZ DO IGUACU')
    end
  end
end
