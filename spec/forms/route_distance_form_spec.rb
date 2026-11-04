require 'rails_helper'

RSpec.describe RouteDistanceForm do
  let!(:tenant) { create(:tenant) }
  let!(:customer) { create(:atua_customer, tenant:, code: 7001) }
  let(:attributes) do
    { customer_code: '7001', origin_city: ' Ipatinga ', origin_state: 'mg', destination_city: 'Caxias do  Sul', destination_state: 'rs',
      distance_km: '1.450,50' }
  end

  describe '#save' do
    let!(:document) do
      create(:atua_transport_document, tenant:, taker_code: 7001, origin_city: 'IPATINGA', origin_state: 'MG', destination_city: 'CAXIAS DO SUL',
                                       destination_state: 'RS', distance_km: BigDecimal('1300'))
    end

    it 'creates the normalized route and applies it to the documents' do
      form = described_class.new(tenant:, **attributes)

      expect { expect(form.save).to be(true) }.to change(RouteDistance, :count).by(1)

      expect(RouteDistance.last).to have_attributes(tenant:, customer_code: 7001, origin_city: 'IPATINGA', origin_state: 'MG',
                                                    destination_city: 'CAXIAS DO SUL', destination_state: 'RS', distance_km: BigDecimal('1450.5'))
      expect(form.documents_count).to eq(1)
      expect(document.reload).to have_attributes(distance_km: BigDecimal('1450.5'), original_distance_km: BigDecimal('1300'))
    end

    it 'leaves the documents for the import to apply' do
      form = described_class.new(tenant:, batch_import: true, **attributes)

      expect { form.save }.to change(RouteDistance, :count).by(1)

      expect(document.reload).to have_attributes(distance_km: BigDecimal('1300'), route_distance_id: nil)
    end

    it 'updates an existing route' do
      route_distance = create(:route_distance, tenant:, customer_code: 7001, distance_km: BigDecimal('900'))
      form = described_class.for_route_distance(route_distance)

      expect(form).to have_attributes(customer_code: '7001', origin_city: 'IPATINGA', distance_km: '900,00')

      form.distance_km = '1520'

      expect { form.save }.not_to change(RouteDistance, :count)
      expect(route_distance.reload.distance_km).to eq(BigDecimal('1520'))
      expect(document.reload.distance_km).to eq(BigDecimal('1520'))
    end
  end

  describe 'validations' do
    it 'requires every field' do
      form = described_class.new(tenant:)

      expect(form).not_to be_valid
      expect(form.errors.attribute_names).to contain_exactly(:customer_code, :origin_city, :origin_state, :destination_city,
                                                             :destination_state, :distance_km)
    end

    it 'requires a state with two letters and a positive distance' do
      form = described_class.new(tenant:, **attributes, origin_state: 'M1', distance_km: '0')

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to eq(['UF de origem não é válido', 'KM considerado deve ser maior que 0'])
    end

    it 'requires a customer of the tenant' do
      stranger = create(:atua_customer, code: 7999)
      form = described_class.new(tenant:, **attributes, customer_code: stranger.code.to_s)

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to eq(['Cliente não foi encontrado no Atua'])
    end

    it 'does not accept the same route twice for the customer' do
      create(:route_distance, tenant:, customer_code: 7001)

      form = described_class.new(tenant:, **attributes)

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to eq(['Este trecho já está cadastrado para o cliente'])
    end

    it 'accepts the route when editing the same record' do
      route_distance = create(:route_distance, tenant:, customer_code: 7001)

      expect(described_class.for_route_distance(route_distance)).to be_valid
    end
  end
end
