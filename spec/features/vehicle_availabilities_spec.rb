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
      visit vehicle_availability_path

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

      visit vehicle_availability_path

      expect(page.status_code).to eq(404)
    end
  end

  context 'when the owner is signed in', flipper: :maintenance do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when the fleet has no vehicles' do
      scenario 'shows the empty state message and zeroed counters' do
        visit vehicle_availability_path

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

        expect(page).to have_current_path(vehicle_availability_path)
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

      scenario 'links to the vehicle and to the maintenance order on the maintenance subdomain' do
        visit vehicle_availability_path

        within("#atua_vehicle_#{tractor_in_shop.id} .inline-actions") do
          expect(page).to have_link('Ver veículo', href: vehicle_path(tractor_in_shop))
          expect(find_link('Ver OS')[:href]).to start_with("http://#{Transjrbi::MAINTENANCE_SUBDOMAIN}.")
          expect(find_link('Ver OS')[:href]).to end_with(maintenance_order_path(MaintenanceOrder.find_by(number: 5)))
        end
      end

      scenario 'filters by availability, vehicle type and plate' do
        visit vehicle_availability_path
        select 'Em manutenção', from: 'Disponibilidade'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows.drop(1).map(&:first)).to eq(['BEV4G50 Carreta', 'EXU1A23 Cavalo'])

        visit vehicle_availability_path
        select 'Disponível', from: 'Disponibilidade'
        select 'Cavalos', from: 'Tipo de veículo'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows.drop(1).map(&:first)).to eq(['GKT4567 Cavalo'])

        visit vehicle_availability_path
        fill_in 'Placa', with: 'exu-1a23'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows.drop(1).map(&:first)).to eq(['EXU1A23 Cavalo'])
        expect(page).to have_css('.counter-card', text: "Cavalos e carretas\n4")
      end

      scenario 'sorts the vehicles by plate' do
        visit vehicle_availability_path
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

    scenario 'sees the order and its estimate without the links it cannot open' do
      visit vehicle_availability_path

      expect(html_table_to_rows).to eq(
        [
          ['Placa', 'Disponibilidade', 'Nº da OS', 'Situação da OS', 'Previsão de término', 'Veículo parado', 'Ações'],
          ['EXU1A23 Cavalo', 'Em manutenção', '5', 'Aberta', '12/11/2026 17:00', 'Não', ''],
        ],
      )
    end
  end

  context 'when a user without access to the screen is signed in', flipper: :maintenance do
    let!(:user) { create(:user, tenant:) }

    before { login_as(user, scope: :user) }

    scenario 'does not show the menu nor open the screen' do
      visit root_path

      expect(page).to have_css('.sidebar-desktop')
      expect(page).to have_no_link('Disponibilidade da frota')

      visit vehicle_availability_path

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
      visit vehicle_availability_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'PLACA')
      expect(page).to have_css('th', text: 'DISPONIBILIDADE')
      expect(page).to have_no_css('th', text: 'PREVISÃO DE TÉRMINO')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
