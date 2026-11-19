require 'rails_helper'

describe 'Vehicle availability' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Disponibilidade da frota', slug: 'vehicle_availability', writable: false) }
  let!(:vehicles_resource) { create(:resource, name: 'Veículos', slug: 'vehicles', writable: false) }
  let!(:orders_resource) { create(:resource, name: 'Ordens de serviço', slug: 'maintenance_orders') }
  let!(:maintenance_resource) { create(:resource, name: 'Módulo de manutenção', slug: 'maintenance', writable: false) }

  before { travel_to(Time.zone.local(2026, 11, 11, 10)) }

  context 'without a signed in user' do
    scenario 'redirects to the login screen' do
      visit vehicle_availabilities_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the maintenance flag is off' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'does not open the screen nor show it on the menu' do
      visit root_path

      expect(page).to have_css('.sidebar-desktop')
      expect(page).to have_no_link('Disponibilidade da frota')

      visit vehicle_availabilities_path

      expect(page.status_code).to eq(404)
    end
  end

  context 'when the owner is signed in', flipper: :maintenance do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when the fleet has no vehicles' do
      scenario 'shows the empty state message and zeroed counters' do
        visit vehicle_availabilities_path

        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_css('.counter-card', text: "Cavalos e carretas\n0")
        expect(page).to have_css('.counter-card', text: "Em manutenção\n0")
      end
    end

    context 'when the fleet has tractors and trailers' do
      let!(:tractor_in_shop) { create(:atua_vehicle, tenant:, plate: 'EXU1A23', category: 'Caminhão / Cavalo', ownership: 'Próprio') }
      let!(:trailer_in_shop) { create(:atua_vehicle, tenant:, plate: 'BEV4G50', category: 'Carreta', ownership: 'Próprio') }
      let!(:available_tractor) { create(:atua_vehicle, tenant:, plate: 'GKT4567', category: 'Caminhão / Cavalo', ownership: 'Próprio') }
      let!(:available_trailer) { create(:atua_vehicle, tenant:, plate: 'AAB1C23', category: 'Carreta', ownership: 'Próprio') }
      let!(:third_party) { create(:atua_vehicle, tenant:, plate: 'TER1A11', category: 'Caminhão / Cavalo', ownership: 'Terceiro') }
      let!(:car) { create(:atua_vehicle, tenant:, plate: 'CAR2B22', category: 'Outros', ownership: 'Próprio') }
      let!(:removed) do
        create(:atua_vehicle, tenant:, plate: 'REM3C33', category: 'Carreta', ownership: 'Próprio', removed_from_atua_at: Time.current)
      end
      let!(:stranger) { create(:atua_vehicle, tenant: other_tenant, plate: 'ZZZ9Z99', category: 'Carreta', ownership: 'Próprio') }

      before do
        create(:maintenance_order, tenant:, number: 1, plate: 'EXU1A23', opened_at: Time.zone.local(2026, 11, 1, 8),
                                   status_type: 'finished', finished_at: Time.zone.local(2026, 11, 2, 8))
        create(:maintenance_order, tenant:, number: 5, plate: 'EXU1A23', opened_at: Time.zone.local(2026, 11, 9, 8),
                                   status_type: 'in_progress', vehicle_stopped: true,
                                   estimated_completion_at: Time.zone.local(2026, 11, 10, 18))
        create(:maintenance_order, tenant:, number: 6, plate: 'BEV4G50', opened_at: Time.zone.local(2026, 11, 10, 8),
                                   status_type: 'waiting_parts', equipment_type: 'trailer',
                                   estimated_completion_at: Time.zone.local(2026, 11, 13, 12))
        create(:maintenance_order, tenant:, number: 7, plate: 'GKT4567', status_type: 'cancelled')
        create(:maintenance_order, tenant: other_tenant, number: 8, plate: 'AAB1C23')
      end

      scenario 'lists the own tractors and trailers with the vehicles in maintenance first' do
        visit root_path
        within('.sidebar-desktop') { click_on 'Disponibilidade da frota' }

        expect(page).to have_current_path(vehicle_availabilities_path)
        expect(Atua::Vehicle.count).to eq(8)
        expect(html_table_to_rows).to eq(
          [
            ['Placa', 'Disponibilidade', 'Nº da OS', 'Situação da OS', 'Previsão de término', 'Veículo parado', 'Ações'],
            ['BEV4G50 Carreta', 'Em manutenção', '6', 'Aguardando peça', '13/11/2026 12:00', 'Não', 'Opções Ver veículo Ver OS'],
            ['EXU1A23 Cavalo', 'Em manutenção', '5', 'Em execução', '10/11/2026 18:00 Atrasada', 'Sim', 'Opções Ver veículo Ver OS'],
            ['AAB1C23 Carreta', 'Disponível', '-', '-', '-', '-', ''],
            ['GKT4567 Cavalo', 'Disponível', '-', '-', '-', '-', ''],
          ],
        )
        expect(page).to have_css('.counter-card', text: "Cavalos e carretas\n4")
        expect(page).to have_css('.counter-card', text: "Disponíveis\n2")
        expect(page).to have_css('.counter-card', text: "Em manutenção\n2")
        expect(page).to have_no_text('TER1A11')
        expect(page).to have_no_text('CAR2B22')
        expect(page).to have_no_text('REM3C33')
        expect(page).to have_no_text('ZZZ9Z99')
      end

      scenario 'links to the vehicle and to the read-only maintenance order on the app' do
        visit vehicle_availabilities_path

        within("#atua_vehicle_#{tractor_in_shop.id} .inline-actions") do
          expect(page).to have_link('Ver veículo', href: vehicle_path(tractor_in_shop, return_to: vehicle_availabilities_path))
          expect(page).to have_link('Ver OS', href: vehicle_availability_order_path(MaintenanceOrder.find_by(number: 5)))
        end
      end

      scenario 'goes back to the fleet availability from the vehicle' do
        visit vehicle_availabilities_path(availability: 'in_maintenance')
        within("#atua_vehicle_#{tractor_in_shop.id} .inline-actions") { click_on 'Ver veículo' }
        find('.btn-back').click

        expect(page).to have_current_path(vehicle_availabilities_path(availability: 'in_maintenance'))
      end

      scenario 'shows the maintenance order without any control to change it' do
        order = MaintenanceOrder.find_by(number: 5)
        create(:maintenance_order_part, maintenance_order: order, description: 'LONA DE FREIO', quantity: 4, unit: 'UN',
                                        unit_price_cents: 8_500, total_cents: 34_000)

        visit vehicle_availabilities_path
        within("#atua_vehicle_#{tractor_in_shop.id} .inline-actions") { click_on 'Ver OS' }

        expect(page).to have_current_path(vehicle_availability_order_path(order))
        expect(page).to have_css('h1', text: 'OS 5 · EXU1A23')
        expect(dl_to_hash('#vehicle_data')).to eq(
          'Nº da OS' => '5', 'Situação' => 'Em execução', 'Abertura' => '09/11/2026 08:00',
          'Previsão de término' => '10/11/2026 18:00 Atrasada', 'Placa' => 'EXU1A23', 'KM' => '-', 'Horímetro' => '-',
          'Motorista' => '-', 'Encarregado responsável' => '-', 'Mecânicos' => '-', 'Tipo de equipamento' => 'Cavalo mecânico',
          'Aberta por' => '-'
        )
        expect(dl_to_hash('#classification')).to eq(
          'Tipo de manutenção' => 'Corretiva', 'Prioridade' => 'Média', 'Veículo parado' => 'Sim',
          'Local de execução' => 'Oficina interna', 'Sistema afetado' => 'Freios'
        )
        expect(dl_to_hash('#description')).to eq(
          'Defeito relatado' => 'Freio puxando para a direita', 'Diagnóstico' => '-', 'Serviço executado' => '-',
        )
        expect(page).to have_css('#parts', text: 'LONA DE FREIO')
        within('.page-shell') do
          expect(page).to have_no_link('Alterar')
          expect(page).to have_no_link('Adicionar peça')
          expect(page).to have_no_button('Iniciar')
          expect(page).to have_no_link('Imprimir OS')
          expect(page).to have_no_css("#maintenance_order_part_#{order.parts.sole.id} a")
        end
      end

      scenario 'does not open a closed order of a vehicle' do
        visit vehicle_availability_order_path(MaintenanceOrder.find_by(number: 1))

        expect(page.status_code).to eq(404)
      end

      scenario 'does not open an order of a vehicle outside the own fleet' do
        visit vehicle_availability_order_path(create(:maintenance_order, tenant:, number: 9, plate: 'TER1A11'))

        expect(page.status_code).to eq(404)
      end

      scenario 'does not open an order of another tenant' do
        visit vehicle_availability_order_path(MaintenanceOrder.find_by(number: 8))

        expect(page.status_code).to eq(404)
      end

      scenario 'sorts the vehicles by plate' do
        visit vehicle_availabilities_path
        within('thead') { click_on 'Placa' }

        expect(html_table_to_rows.drop(1).map(&:first)).to eq(['AAB1C23 Carreta', 'BEV4G50 Carreta', 'EXU1A23 Cavalo', 'GKT4567 Cavalo'])
      end
    end
  end

  context 'when a logistics user without access to the maintenance module is signed in', flipper: :maintenance do
    let!(:user) { create(:user, tenant:, name: 'Lucas Logística') }
    let!(:vehicle) { create(:atua_vehicle, tenant:, plate: 'EXU1A23', category: 'Caminhão / Cavalo', ownership: 'Próprio') }

    before do
      create(:access, user:, resource:, reads: true)
      create(:maintenance_order, tenant:, number: 5, plate: 'EXU1A23', estimated_completion_at: Time.zone.local(2026, 11, 12, 17))
      login_as(user, scope: :user)
    end

    scenario 'sees the order and its estimate and opens the order only to read it' do
      visit vehicle_availabilities_path

      expect(html_table_to_rows).to eq(
        [
          ['Placa', 'Disponibilidade', 'Nº da OS', 'Situação da OS', 'Previsão de término', 'Veículo parado', 'Ações'],
          ['EXU1A23 Cavalo', 'Em manutenção', '5', 'Aberta', '12/11/2026 17:00', 'Não', ''],
        ],
      )
      expect(page).to have_no_link('Ver veículo')

      click_on 'Ver OS'

      expect(page).to have_css('h1', text: 'OS 5 · EXU1A23')
      expect(dl_to_hash('#vehicle_data')).to include('Previsão de término' => '12/11/2026 17:00')
    end

    scenario 'still cannot enter the maintenance module', :maintenance do
      visit maintenance_order_path(MaintenanceOrder.find_by(number: 5))

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when a user without access to the screen is signed in', flipper: :maintenance do
    let!(:user) { create(:user, tenant:) }

    before { login_as(user, scope: :user) }

    scenario 'does not show the menu nor open the screen' do
      visit root_path

      expect(page).to have_css('.sidebar-desktop')
      expect(page).to have_no_link('Disponibilidade da frota')

      visit vehicle_availabilities_path

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end
  end

  context 'when the screen is opened on a phone', :js, flipper: :maintenance do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }
    let!(:vehicle) { create(:atua_vehicle, tenant:, plate: 'EXU1A23', category: 'Caminhão / Cavalo', ownership: 'Próprio') }

    before do
      create(:maintenance_order, tenant:, plate: 'EXU1A23')
      login_as(owner, scope: :user)
    end

    scenario 'keeps the plate and the availability and does not scroll sideways' do
      visit vehicle_availabilities_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'PLACA')
      expect(page).to have_css('th', text: 'DISPONIBILIDADE')
      expect(page).to have_no_css('th', text: 'PREVISÃO DE TÉRMINO')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
