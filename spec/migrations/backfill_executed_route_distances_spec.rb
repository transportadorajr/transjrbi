require 'rails_helper'
require Rails.root.join('db/migrate/20261104231308_backfill_executed_route_distances')

RSpec.describe BackfillExecutedRouteDistances do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  let!(:tenant) { create(:tenant) }

  def document(number, **attributes)
    create(:atua_transport_document, tenant:, number:, taker_code: 753, origin_city: 'SANTA GERTRUDES', origin_state: 'SP',
                                     destination_city: 'FOZ DO IGUACU', destination_state: 'PR', distance_km: BigDecimal('932'), **attributes)
  end

  context 'with the transport documents of the executed routes' do
    let!(:panorama) { document('75147') }
    let!(:same_route) { document('75999') }
    let!(:sooro) do
      document('75122', taker_code: 5317, origin_city: 'MARECHAL CANDIDO RONDON', destination_city: 'CONTAGEM', destination_state: 'MG',
                        distance_km: BigDecimal('1355'))
    end
    let!(:canceled) { document('424', taker_code: 63, destination_city: 'PARANAVAI', canceled_at: 1.day.ago) }
    let!(:previous_route) do
      create(:route_distance, tenant:, customer_code: 5317, origin_city: 'MARECHAL CANDIDO RONDON', origin_state: 'PR',
                              destination_city: 'CONTAGEM', destination_state: 'MG', distance_km: BigDecimal('1400'))
    end

    before { sooro.update!(origin_state: 'PR') }

    it 'registers the route of each document with the executed distance' do
      expect { migration.up }.to change(RouteDistance, :count).by(1)

      expect(RouteDistance.order(:customer_code).pluck(:customer_code, :origin_city, :destination_city, :distance_km))
        .to eq([[753, 'SANTA GERTRUDES', 'FOZ DO IGUACU', BigDecimal('1031')], [5317, 'MARECHAL CANDIDO RONDON', 'CONTAGEM', BigDecimal('1448')]])
      expect(previous_route.reload.distance_km).to eq(BigDecimal('1448'))
    end

    it 'applies the executed distance to every document of the route' do
      migration.up

      expect(panorama.reload).to have_attributes(distance_km: BigDecimal('1031'), original_distance_km: BigDecimal('932'))
      expect(same_route.reload).to have_attributes(distance_km: BigDecimal('1031'), original_distance_km: BigDecimal('932'))
      expect(sooro.reload).to have_attributes(distance_km: BigDecimal('1448'), original_distance_km: BigDecimal('1355'))
      expect(canceled.reload).to have_attributes(distance_km: BigDecimal('932'), route_distance_id: nil)
    end

    it 'does not duplicate the routes when it runs again' do
      migration.up

      expect { migration.up }.not_to change(RouteDistance, :count)
    end
  end
end
