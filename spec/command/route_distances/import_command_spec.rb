require 'rails_helper'

RSpec.describe RouteDistances::ImportCommand do
  let!(:tenant) { create(:tenant) }
  let!(:customer) { create(:atua_customer, tenant:, code: 7001, document_digits: '17469701006612') }
  let!(:document) do
    create(:atua_transport_document, tenant:, taker_code: 7001, origin_city: 'IPATINGA', origin_state: 'MG', destination_city: 'CAXIAS DO SUL',
                                     destination_state: 'RS', distance_km: BigDecimal('1300'))
  end

  context 'with a header and valid rows' do
    let(:path) do
      xlsx_file([%w[Cliente Origem UF Destino UF KM], ['17.469.701/0066-12', 'Ipatinga', 'mg', 'Caxias do Sul', 'RS', 1450.5],
                 [17_469_701_006_612, 'SERRA', 'ES', 'CURITIBA', 'PR', '610,00']])
    end

    it 'creates the routes and applies them to the documents' do
      result = nil

      expect { result = described_class.call(tenant, path, '.xlsx') }.to change(RouteDistance, :count).by(2)

      expect(result).to have_attributes(created: 2, updated: 0, documents: 1, errors: [])
      expect(tenant.route_distances.order(:origin_city).pluck(:customer_code, :origin_city, :origin_state, :destination_city, :destination_state,
                                                              :distance_km))
        .to eq([[7001, 'IPATINGA', 'MG', 'CAXIAS DO SUL', 'RS', BigDecimal('1450.5')], [7001, 'SERRA', 'ES', 'CURITIBA', 'PR', BigDecimal('610')]])
      expect(document.reload).to have_attributes(distance_km: BigDecimal('1450.5'), original_distance_km: BigDecimal('1300'))
    end
  end

  context 'with a route already registered' do
    let!(:route_distance) { create(:route_distance, tenant:, customer_code: 7001, distance_km: BigDecimal('1400')) }
    let(:path) { xlsx_file([['17469701006612', 'IPATINGA', 'MG', 'CAXIAS DO SUL', 'RS', 1520]]) }

    it 'updates the route and the distance of its documents' do
      result = nil

      expect { result = described_class.call(tenant, path, '.xlsx') }.not_to change(RouteDistance, :count)

      expect(result).to have_attributes(created: 0, updated: 1, documents: 1)
      expect(route_distance.reload.distance_km).to eq(BigDecimal('1520'))
      expect(document.reload).to have_attributes(distance_km: BigDecimal('1520'), original_distance_km: BigDecimal('1300'))
    end
  end

  context 'with invalid rows' do
    let(:path) do
      xlsx_file([['99.999.999/0001-99', 'IPATINGA', 'MG', 'CAXIAS DO SUL', 'RS', 1450],
                 ['17469701006612', 'IPATINGA', 'MINAS', 'CAXIAS DO SUL', 'RS', 0]])
    end

    it 'reports each line without creating routes' do
      result = nil

      expect { result = described_class.call(tenant, path, '.xlsx') }.not_to change(RouteDistance, :count)

      expect(result.errors).to eq(
        [
          'Linha 1: nenhum cliente do Atua com o CPF/CNPJ 99.999.999/0001-99.',
          'Linha 2: UF de origem não é válido e KM considerado deve ser maior que 0.',
        ],
      )
    end
  end

  context 'with a file that is not a spreadsheet' do
    let(:path) { Tempfile.new(%w[route_distances .xlsx]).tap { |file| file.write('texto') }.tap(&:close).path }

    it 'reports that the file could not be read' do
      result = described_class.call(tenant, path, '.xlsx')

      expect(result.errors.first).to start_with('Não foi possível ler a planilha')
    end
  end
end
