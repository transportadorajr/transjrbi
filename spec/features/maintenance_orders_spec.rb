require 'rails_helper'

describe 'Maintenance orders' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Ordens de serviço', slug: 'maintenance_orders') }

  before { travel_to(Time.zone.local(2026, 11, 11, 10)) }

  context 'without a signed in user' do
    scenario 'redirects the listing to the login screen' do
      visit maintenance_orders_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the maintenance flag is off' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'hides the menu and does not open the listing' do
      visit root_path

      expect(page).to have_css('.sidebar-desktop')
      expect(page).to have_no_link('Ordens de serviço')

      visit maintenance_orders_path

      expect(page.status_code).to eq(404)
    end
  end

  context 'when the owner is signed in', flipper: :maintenance do
    let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are no maintenance orders' do
      scenario 'shows the empty state message and zeroed counters' do
        visit maintenance_orders_path

        expect(MaintenanceOrder.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
        expect(page).to have_css('.counter-card', text: "Em aberto\n0")
      end
    end

    context 'when there are maintenance orders' do
      let!(:supervisor) { create(:workshop_employee, tenant:, name: 'PAULO LIMA', role_type: 'supervisor') }
      let!(:brakes_order) do
        create(:maintenance_order, tenant:, number: 1, plate: 'EXU1A23', opened_at: Time.zone.local(2026, 11, 3, 7, 15),
                                   supervisor:, opened_by: owner, odometer_km: 452_300, hour_meter: BigDecimal('1250.5'),
                                   driver_code: 501, driver_name: 'JOSE DA SILVA', vehicle_stopped: true, priority_type: 'high',
                                   diagnosis: 'Lonas gastas', performed_service: "Troca das lonas\nRegulagem do freio")
      end
      let!(:tire_order) do
        create(:maintenance_order, tenant:, number: 2, plate: 'GKT4567', opened_at: Time.zone.local(2026, 11, 5, 14, 0),
                                   equipment_type: 'other', equipment_other: 'GUINDASTE', maintenance_type: 'preventive',
                                   priority_type: 'low', affected_system_type: 'tires', status_type: 'finished',
                                   finished_at: Time.zone.local(2026, 11, 6, 9), reported_defect: 'Rodízio de pneus')
      end
      let!(:engine_order) do
        create(:maintenance_order, tenant:, number: 3, plate: 'EXU9B87', opened_at: Time.zone.local(2026, 11, 10, 16, 40),
                                   maintenance_type: 'roadside', affected_system_type: 'engine', status_type: 'waiting_parts',
                                   execution_place_type: 'on_route', reported_defect: 'Motor falhando')
      end
      let!(:stranger_order) { create(:maintenance_order, tenant: other_tenant, number: 4, plate: 'ZZZ9Z99') }

      scenario 'lists the orders from the maintenance menu, newest first' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Manutenção'
          click_on 'Ordens de serviço'
        end

        expect(page).to have_current_path(maintenance_orders_path)
        expect(MaintenanceOrder.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            ['Nº da OS', 'Placa', 'Abertura', 'Tipo de manutenção', 'Prioridade', 'Sistema afetado', 'Situação', 'Ações'],
            ['3', 'EXU9B87', '10/11/2026 16:40', 'Socorro (em rota)', 'Média', 'Motor', 'Aguardando peça', 'Opções Visualizar Alterar'],
            ['2', 'GKT4567', '05/11/2026 14:00', 'Preventiva', 'Baixa', 'Pneus / Rodas', 'Concluída', ''],
            ['1', 'EXU1A23', '03/11/2026 07:15', 'Corretiva', 'Alta', 'Freios', 'Aberta', 'Opções Visualizar Alterar'],
          ],
        )
        expect(page).to have_css('.counter-card', text: "Em aberto\n2")
        expect(page).to have_css('.counter-card', text: "Veículos parados\n1")
        expect(page).to have_css('.counter-card', text: "Concluídas no mês\n1")
        expect(page).to have_link('Nova OS', href: new_maintenance_order_path)
        expect(page).to have_no_text('ZZZ9Z99')
      end

      scenario 'filters the orders by number, plate, status, type and priority' do
        visit maintenance_orders_path
        fill_in 'Placa', with: 'exu'
        select 'Aberta', from: 'Situação'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows.drop(1).map(&:first)).to eq(['1'])

        visit maintenance_orders_path
        select 'Socorro (em rota)', from: 'Tipo de manutenção'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows.drop(1).map(&:first)).to eq(['3'])

        visit maintenance_orders_path
        fill_in 'Nº da OS', with: '2'
        select 'Baixa', from: 'Prioridade'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows.drop(1).map(&:first)).to eq(['2'])
      end

      scenario 'filters the orders by opening period and affected system' do
        visit maintenance_orders_path
        fill_in 'Abertas a partir de', with: '2026-11-04'
        fill_in 'Abertas até', with: '2026-11-10'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows.drop(1).map(&:first)).to eq(%w[3 2])

        visit maintenance_orders_path
        fill_in 'Abertas até', with: '2026-11-05'
        select 'Freios', from: 'Sistema afetado'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows.drop(1).map(&:first)).to eq(['1'])
      end

      scenario 'ignores an invalid opening date' do
        visit maintenance_orders_path(start_date: '2026-13-45')

        expect(html_table_to_rows.drop(1).map(&:first)).to eq(%w[3 2 1])
      end

      scenario 'sorts the orders by plate and by opening' do
        visit maintenance_orders_path
        within('thead') { click_on 'Placa' }

        expect(html_table_to_rows.drop(1).map(&:second)).to eq(%w[EXU1A23 EXU9B87 GKT4567])

        within('thead') { click_on 'Abertura' }

        expect(html_table_to_rows.drop(1).map(&:second)).to eq(%w[EXU9B87 GKT4567 EXU1A23])
      end

      scenario 'shows every data of an order' do
        visit maintenance_orders_path
        within("#maintenance_order_#{brakes_order.id} .inline-actions") { click_on 'Visualizar' }

        expect(page).to have_current_path(maintenance_order_path(brakes_order))
        expect(page).to have_css('h1', text: 'OS 1 · EXU1A23')
        expect(dl_to_hash('#vehicle_data')).to eq(
          'Nº da OS' => '1', 'Situação' => 'Aberta', 'Abertura' => '03/11/2026 07:15', 'Placa' => 'EXU1A23',
          'KM' => '452.300 km', 'Horímetro' => '1.250,5 h', 'Motorista' => 'JOSE DA SILVA',
          'Encarregado responsável' => 'PAULO LIMA', 'Tipo de equipamento' => 'Cavalo mecânico', 'Aberta por' => 'Bruna Dona'
        )
        expect(dl_to_hash('#classification')).to eq(
          'Tipo de manutenção' => 'Corretiva', 'Prioridade' => 'Alta', 'Veículo parado' => 'Sim',
          'Local de execução' => 'Oficina interna', 'Sistema afetado' => 'Freios'
        )
        expect(dl_to_hash('#description')).to eq(
          'Defeito relatado' => 'Freio puxando para a direita', 'Diagnóstico' => 'Lonas gastas',
          'Serviço executado' => 'Troca das lonas Regulagem do freio'
        )
      end

      scenario 'shows the blank fields and the description of another equipment' do
        visit maintenance_order_path(tire_order)

        expect(dl_to_hash('#vehicle_data')).to include('KM' => '-', 'Horímetro' => '-', 'Motorista' => '-',
                                                       'Encarregado responsável' => '-', 'Tipo de equipamento' => 'Outro: GUINDASTE',
                                                       'Aberta por' => '-')
        expect(dl_to_hash('#classification')).to include('Veículo parado' => 'Não')
        expect(dl_to_hash('#description')).to include('Diagnóstico' => '-', 'Serviço executado' => '-')
      end

      scenario 'fills the diagnosis and the service of an order' do
        visit maintenance_order_path(engine_order)
        within('.page-header') { click_on 'Alterar' }

        fill_in 'Diagnóstico', with: 'Bico injetor entupido'
        fill_in 'Serviço executado', with: 'Limpeza dos bicos injetores'
        fill_in 'KM', with: '610200'
        select 'PAULO LIMA', from: 'Encarregado responsável'

        expect { click_on 'Salvar Alterações' }.not_to change(MaintenanceOrder, :count)

        expect(page).to have_current_path(maintenance_order_path(engine_order))
        expect(page).to have_text('Ordem de serviço atualizada com sucesso.')
        expect(engine_order.reload).to have_attributes(number: 3, plate: 'EXU9B87', diagnosis: 'Bico injetor entupido',
                                                       performed_service: 'Limpeza dos bicos injetores', odometer_km: 610_200,
                                                       supervisor:, reported_defect: 'Motor falhando')
      end

      scenario 'does not open an order of another tenant' do
        visit maintenance_order_path(stranger_order)

        expect(page.status_code).to eq(404)
      end

      scenario 'does not update an order of another tenant' do
        page.driver.submit :patch, maintenance_order_path(stranger_order), { maintenance_order: { diagnosis: 'Invadido' } }

        expect(page.status_code).to eq(404)
        expect(stranger_order.reload.diagnosis).to be_nil
      end

      scenario 'does not delete an order' do
        expect { page.driver.submit :delete, maintenance_order_path(brakes_order), {} }.not_to change(MaintenanceOrder, :count)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when opening an order' do
      let!(:vehicle) { create(:atua_vehicle, tenant:, plate: 'EXU1A23', driver_code: 501, driver_name: 'JOSE DA SILVA') }
      let!(:other_vehicle) { create(:atua_vehicle, tenant:, plate: 'GKT4567') }
      let!(:supervisor) { create(:workshop_employee, tenant:, name: 'PAULO LIMA', role_type: 'supervisor') }
      let!(:inactive_supervisor) { create(:workshop_employee, tenant:, name: 'ANTIGO ENCARREGADO', role_type: 'supervisor', active: false) }
      let!(:mechanic) { create(:workshop_employee, tenant:, name: 'CARLOS SOUZA') }
      let!(:last_order) { create(:maintenance_order, tenant:, number: 41, plate: 'GKT4567') }

      scenario 'opens an order with the next number', :js do
        visit maintenance_orders_path
        click_on 'Nova OS'

        within('#plate_select') do
          find('.select2-trigger').click
          find('.select2-search').fill_in(with: 'exu')
          find('.select2-option', text: 'EXU1A23').click
        end
        within('#driver_code_select') do
          find('.select2-trigger').click
          find('.select2-option', text: 'JOSE DA SILVA').click
        end
        fill_in 'KM', with: '452300'
        expect(page).to have_no_select('Encarregado responsável', with_options: ['ANTIGO ENCARREGADO', 'CARLOS SOUZA'])
        select 'PAULO LIMA', from: 'Encarregado responsável'
        select 'Cavalo mecânico', from: 'Tipo de equipamento'
        select 'Corretiva', from: 'Tipo de manutenção'
        select 'Alta', from: 'Prioridade'
        select 'Freios', from: 'Sistema afetado'
        check 'Veículo parado'
        fill_in 'Defeito relatado', with: 'Freio puxando para a direita'
        click_on 'Abrir OS'

        expect(page).to have_text('OS 42 aberta com sucesso.')
        maintenance_order = MaintenanceOrder.last
        expect(page).to have_current_path(maintenance_order_path(maintenance_order))
        expect(MaintenanceOrder.count).to eq(2)
        expect(maintenance_order).to have_attributes(
          tenant:, number: 42, plate: 'EXU1A23', opened_at: Time.zone.local(2026, 11, 11, 10), odometer_km: 452_300,
          driver_code: 501, driver_name: 'JOSE DA SILVA', supervisor:, opened_by: owner, equipment_type: 'truck_tractor',
          maintenance_type: 'corrective', priority_type: 'high', vehicle_stopped: true, execution_place_type: 'internal_workshop',
          affected_system_type: 'brakes', reported_defect: 'Freio puxando para a direita', status_type: 'open'
        )
      end

      scenario 'opens an order for a foreign plate registered in Atua', :js do
        create(:atua_vehicle, tenant:, plate: 'AAOP898')

        visit new_maintenance_order_path
        within('#plate_select') do
          find('.select2-trigger').click
          find('.select2-search').fill_in(with: 'aaop')
          find('.select2-option', text: 'AAOP898').click
        end
        select 'Carreta / Semirreboque', from: 'Tipo de equipamento'
        select 'Preventiva', from: 'Tipo de manutenção'
        select 'Pneus / Rodas', from: 'Sistema afetado'
        fill_in 'Defeito relatado', with: 'Rodízio de pneus'
        click_on 'Abrir OS'

        expect(page).to have_text('OS 42 aberta com sucesso.')
        expect(MaintenanceOrder.count).to eq(2)
        expect(MaintenanceOrder.last).to have_attributes(tenant:, number: 42, plate: 'AAOP898', equipment_type: 'trailer',
                                                         maintenance_type: 'preventive', affected_system_type: 'tires')
      end

      scenario 'shows the errors of an incomplete order' do
        visit new_maintenance_order_path

        expect { click_on 'Abrir OS' }.not_to change(MaintenanceOrder, :count)

        expect(page).to have_text('Placa não pode ficar em branco')
        expect(page).to have_text('Defeito relatado não pode ficar em branco')
      end
    end
  end

  context 'when the workshop user is signed in', flipper: :maintenance do
    let!(:workshop_user) { create(:user, tenant:, name: 'Rafael Oficina') }
    let!(:access) { create(:access, user: workshop_user, resource:, reads: true, creates: true) }
    let!(:maintenance_order) { create(:maintenance_order, tenant:, number: 1) }

    before { login_as(workshop_user, scope: :user) }

    scenario 'sees only the maintenance menu and can open an order' do
      visit maintenance_orders_path

      expect(page.all('.sidebar-desktop .nav-link').map { it.text.squish }.compact_blank).to eq(['Manutenção', 'Ordens de serviço'])
      expect(html_table_to_rows.drop(1).map(&:first)).to eq(['1'])
      expect(page).to have_link('Nova OS', href: new_maintenance_order_path)
    end
  end

  context 'when a user without access to the maintenance orders is signed in', flipper: :maintenance do
    let!(:operator) { create(:user, tenant:) }

    before { login_as(operator, scope: :user) }

    scenario 'cannot open the listing nor create an order' do
      visit maintenance_orders_path

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')

      expect do
        page.driver.submit :post, maintenance_orders_path, { maintenance_order: { plate: 'EXU1A23', reported_defect: 'Freio' } }
      end.not_to change(MaintenanceOrder, :count)
    end
  end

  context 'when the screen is opened on a phone', :js, flipper: :maintenance do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }
    let!(:maintenance_order) { create(:maintenance_order, tenant:, number: 1) }

    before { login_as(owner, scope: :user) }

    scenario 'keeps the essential columns and collapses the actions into a menu' do
      visit maintenance_orders_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'PLACA')
      expect(page).to have_no_css('th', text: 'PRIORIDADE')

      within("#maintenance_order_#{maintenance_order.id}") do
        click_button 'Opções'
        click_on 'Alterar'
      end

      expect(page).to have_current_path(edit_maintenance_order_path(maintenance_order))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
