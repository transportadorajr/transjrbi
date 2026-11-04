require 'rails_helper'

RSpec.describe RouteDistances::DestroyCommand do
  let!(:tenant) { create(:tenant) }
  let!(:route_distance) { create(:route_distance, tenant:, customer_code: 7001, distance_km: BigDecimal('1450')) }
  let!(:document) do
    create(:atua_transport_document, tenant:, taker_code: 7001, origin_city: 'IPATINGA', origin_state: 'MG', destination_city: 'CAXIAS DO SUL',
                                     destination_state: 'RS', distance_km: BigDecimal('1300'))
  end

  before { RouteDistances::ApplyCommand.call(tenant) }

  it 'removes the route and restores the distance from Atua of its documents' do
    expect { described_class.call(route_distance) }.to change(RouteDistance, :count).by(-1)

    expect(document.reload).to have_attributes(distance_km: BigDecimal('1300'), original_distance_km: nil, route_distance_id: nil,
                                               distance_adjusted_at: nil)
  end
end
