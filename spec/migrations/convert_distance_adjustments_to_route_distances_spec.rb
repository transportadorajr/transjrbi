require 'rails_helper'
require Rails.root.join('db/migrate/20261104224812_convert_distance_adjustments_to_route_distances')

RSpec.describe ConvertDistanceAdjustmentsToRouteDistances do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  let!(:tenant) { create(:tenant) }

  def document(number, **attributes)
    create(:atua_transport_document, tenant:, number:, taker_code: 7001, origin_city: 'IPATINGA', origin_state: 'MG',
                                     destination_city: 'CAXIAS DO SUL', destination_state: 'RS', **attributes)
  end

  def adjustment(number, distance_km, updated_at: Time.current)
    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      INSERT INTO distance_adjustments (tenant_id, transport_document_number, distance_km, created_at, updated_at)
      VALUES (#{tenant.id}, '#{number}', #{distance_km}, NOW(), '#{updated_at.iso8601}')
    SQL
  end

  context 'with adjustments of transport documents on the same route' do
    before do
      document('74120')
      document('74121')
      document('74122')
      document('74130', destination_city: 'PORTO ALEGRE')
      document('74140', taker_code: nil)
      adjustment('74120', 1450, updated_at: 2.days.ago)
      adjustment('74121', 1450, updated_at: 2.days.ago)
      adjustment('74122', 1500, updated_at: 1.day.ago)
      adjustment('74130', 1300)
      adjustment('74140', 900)
      adjustment('99999', 700)
    end

    it 'creates a route per customer, origin and destination with the distance of most documents' do
      expect { migration.up }.to change(RouteDistance, :count).by(2)

      expect(RouteDistance.order(:destination_city).pluck(:tenant_id, :customer_code, :origin_city, :origin_state, :destination_city,
                                                          :destination_state, :distance_km))
        .to eq([[tenant.id, 7001, 'IPATINGA', 'MG', 'CAXIAS DO SUL', 'RS', BigDecimal('1450')],
                [tenant.id, 7001, 'IPATINGA', 'MG', 'PORTO ALEGRE', 'RS', BigDecimal('1300')]])
    end

    it 'does not duplicate the routes when it runs again' do
      migration.up

      expect { migration.up }.not_to change(RouteDistance, :count)
    end
  end
end
