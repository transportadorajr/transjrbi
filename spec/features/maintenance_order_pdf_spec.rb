require 'rails_helper'

describe 'Maintenance order PDF', flipper: :maintenance do
  let!(:tenant) { create(:tenant, trade_name: 'Transportadora JR') }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Ordens de serviço', slug: 'maintenance_orders') }
  let!(:supervisor) { create(:workshop_employee, tenant:, name: 'PAULO LIMA', role_type: 'supervisor') }
  let!(:mechanic) { create(:workshop_employee, tenant:, name: 'CARLOS SOUZA') }
  let!(:supplier) { create(:supplier, tenant:, name: 'RETÍFICA IPATINGA') }
  let!(:maintenance_order) do
    create(:maintenance_order, tenant:, number: 7, plate: 'EXU1A23', opened_at: Time.zone.local(2026, 11, 11, 8), odometer_km: 452_300,
                               driver_name: 'JOSE DA SILVA', supervisor:, priority_type: 'high', vehicle_stopped: true,
                               diagnosis: 'Lonas gastas', performed_service: 'Troca das lonas', status_type: 'finished',
                               finished_at: Time.zone.local(2026, 11, 11, 17, 30), release_test_type: 'road_test',
                               next_preventive_km: 482_300)
  end
  let!(:part) do
    create(:maintenance_order_part, maintenance_order:, code: 'LF-123', description: 'LONA DE FREIO', quantity: 4, unit: 'UN',
                                    unit_price_cents: 8_500, total_cents: 34_000)
  end
  let!(:labor) do
    create(:maintenance_order_labor, maintenance_order:, workshop_employee: mechanic, worked_on: Date.new(2026, 11, 11),
                                     start_time: '08:00', end_time: '10:30', hours: 2.5, activity: 'Troca das lonas')
  end
  let!(:service) do
    create(:maintenance_order_service, maintenance_order:, supplier:, description: 'Retífica do tambor', quoted_cents: 45_000,
                                       approved_cents: 42_000, approved_by_name: 'MARCOS')
  end
  let!(:stranger_order) { create(:maintenance_order, tenant: other_tenant, number: 7) }

  before do
    travel_to(Time.zone.local(2026, 11, 12, 9))
    MaintenanceOrders::RecalculateTotalsCommand.call(maintenance_order)
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'prints the order with every section of the form' do
      visit maintenance_order_path(maintenance_order)

      expect(page).to have_link('Imprimir OS', href: maintenance_order_path(maintenance_order, format: :pdf))

      visit maintenance_order_path(maintenance_order, format: :pdf)

      expect(page.response_headers['Content-Type']).to include('application/pdf')
      expect(page.response_headers['Content-Disposition']).to include('inline').and include('os_7.pdf')

      text = pdf_text
      expect(text).to include('Ficha da Ordem de Serviço nº 7 - Transportadora JR')
      expect(text).to include('Manutenção da frota · Placa EXU1A23 · Concluída')
      expect(text).to include('EXU1A23', '452.300 km', 'JOSE DA SILVA', 'PAULO LIMA', 'Cavalo mecânico')
      expect(text).to include('Corretiva', 'Alta', 'Oficina interna', 'Freios')
      expect(text).to include('Freio puxando para a direita', 'Lonas gastas', 'Troca das lonas')
      expect(text).to include('LF-123', 'LONA DE FREIO', '4 UN', 'R$ 85,00', 'R$ 340,00')
      expect(text).to include('CARLOS SOUZA', '08:00 às 10:30', '2,5 h')
      expect(text).to include('RETÍFICA IPATINGA', 'Retífica do tambor', 'R$ 450,00', 'R$ 420,00', 'MARCOS')
      expect(text).to include('R$ 760,00')
      expect(text).to include('11/11/2026 17:30', 'Rodagem', '482.300 km')
      expect(text).to include('PAULO LIMAEncarregado responsável')
      expect(text).not_to include('Mecânico responsável', 'Motorista (veículo liberado)', 'Compras (aprovação)')
      expect(text).to include('Gerado em 12/11/2026 09:00.')
    end

    scenario 'prints an order without items' do
      empty_order = create(:maintenance_order, tenant:, number: 8)

      visit maintenance_order_path(empty_order, format: :pdf)

      text = pdf_text
      expect(text).to include('Nenhuma peça lançada nesta OS.', 'Nenhuma mão de obra lançada nesta OS.',
                              'Nenhum serviço terceirizado lançado nesta OS.')
      expect(text).to include('R$ 0,00')
    end

    scenario 'does not print an order of another tenant' do
      visit maintenance_order_path(stranger_order, format: :pdf)

      expect(page.status_code).to eq(404)
    end
  end

  context 'when a user without access to the maintenance orders is signed in' do
    let!(:operator) { create(:user, tenant:) }

    before { login_as(operator, scope: :user) }

    scenario 'does not print the order' do
      visit maintenance_order_path(maintenance_order, format: :pdf)

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end
  end

  def pdf_text
    PDF::Inspector::Text.analyze(page.body).strings.join
  end
end
