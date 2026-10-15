require 'rails_helper'

describe 'Vehicles' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Veículos', slug: 'vehicles', writable: false) }

  context 'without a signed in user' do
    let!(:vehicle) { create(:atua_vehicle, tenant:) }

    scenario 'redirects the listing to the login screen' do
      visit vehicles_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'redirects the details to the login screen' do
      visit vehicle_path(vehicle)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when there are no vehicles' do
      scenario 'shows the empty state message' do
        visit vehicles_path

        expect(Atua::Vehicle.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are vehicles' do
      let!(:truck) do
        create(:atua_vehicle, tenant:, plate: 'EXU0F72', brand: 'VOLVO', model: 'FH 540', manufacture_year: 2021, model_year: 2022,
                              category: 'Caminhão / Cavalo', ownership: 'Próprio', driver_code: 760, driver_name: 'JOSE DA SILVA')
      end
      let!(:trailer) do
        create(:atua_vehicle, tenant:, plate: 'BEV4G50', brand: nil, model: nil, manufacture_year: nil, model_year: nil,
                              category: 'Carreta', ownership: 'Terceiro', driver_code: nil, driver_name: nil)
      end
      let!(:removed) { create(:atua_vehicle, tenant:, plate: 'AGL9451', category: 'Outros', removed_from_atua_at: Time.current) }
      let!(:stranger) { create(:atua_vehicle, tenant: other_tenant, plate: 'ZIZ7D35', category: 'Bitrem') }

      scenario 'lists the active vehicles of the tenant from the registrations menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Veículos'
        end

        expect(page).to have_current_path(vehicles_path)
        expect(Atua::Vehicle.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            ['Placa', 'Categoria', 'Ano fabricação/modelo', 'Propriedade', 'Motorista', 'Ações'],
            ['BEV4G50 -', 'Carreta', '-', 'Terceiro', '-', ''],
            ['EXU0F72 VOLVO FH 540', 'Caminhão / Cavalo', '2021/2022', 'Próprio', 'JOSE DA SILVA', ''],
          ],
        )
        expect(page).to have_text('2 registros')
        expect(page).to have_link(href: vehicle_path(truck), title: 'Visualizar')
        expect(page).to have_no_text('AGL9451')
        expect(page).to have_no_text('ZIZ7D35')
      end

      scenario 'offers only the categories and ownerships of the active vehicles of the tenant' do
        visit vehicles_path

        expect(page).to have_select('Categoria', options: ['Todos', 'Caminhão / Cavalo', 'Carreta'])
        expect(page).to have_select('Propriedade', options: %w[Todos Próprio Terceiro])
      end

      scenario 'filters the vehicles by plate' do
        visit vehicles_path
        fill_in 'Placa', with: 'exu-0f72'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Placa', 'Categoria', 'Ano fabricação/modelo', 'Propriedade', 'Motorista', 'Ações'],
            ['EXU0F72 VOLVO FH 540', 'Caminhão / Cavalo', '2021/2022', 'Próprio', 'JOSE DA SILVA', ''],
          ],
        )
      end

      scenario 'filters the vehicles by category and ownership' do
        visit vehicles_path
        select 'Carreta', from: 'Categoria'
        select 'Terceiro', from: 'Propriedade'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Placa', 'Categoria', 'Ano fabricação/modelo', 'Propriedade', 'Motorista', 'Ações'],
            ['BEV4G50 -', 'Carreta', '-', 'Terceiro', '-', ''],
          ],
        )
      end

      scenario 'does not show a vehicle removed from Atua' do
        visit vehicle_path(removed)

        expect(page.status_code).to eq(404)
      end

      scenario 'does not show a vehicle of another tenant' do
        visit vehicle_path(stranger)

        expect(page.status_code).to eq(404)
      end

      scenario 'has no route to create a vehicle' do
        expect { page.driver.submit :post, vehicles_path, {} }.not_to change(Atua::Vehicle, :count)

        expect(page.status_code).to eq(404)
      end

      scenario 'has no route to remove a vehicle' do
        expect { page.driver.submit :delete, vehicle_path(truck), {} }.not_to change(Atua::Vehicle, :count)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when a vehicle has every detail' do
      let!(:drivers_resource) { create(:resource, name: 'Motoristas', slug: 'drivers', writable: false) }
      let!(:expenses_resource) { create(:resource, name: 'Despesas', slug: 'expenses', writable: false) }
      let!(:transport_documents_resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }
      let!(:vehicle) do
        create(:atua_vehicle, tenant:, code: 812, plate: 'EXU0F72', category: 'Caminhão / Cavalo', vehicle_kind: 'TRUCK', brand: 'VOLVO',
                              model: 'FH 540', manufacture_year: 2021, model_year: 2022, color: 'BRANCA', body: 'NAO APLICAVEL',
                              wheelset: 'TRUCK', chassis: '9BVRG40D5ME123456', renavam: '01234567890', antt: '012345678',
                              city: 'IPATINGA', state: 'MG', status: 'Normal', risk_status: 'Liberado',
                              data_expires_on: Date.new(2027, 3, 31), ownership: 'Agregado', owner_name: 'JR TRANSPORTES LTDA',
                              owner_document: '12.345.678/0001-90', driver_code: 760, driver_name: 'JOSE DA SILVA',
                              driver_document: '808.542.250-64', driver_license: '604269044')
      end

      scenario 'shows every detail of the vehicle' do
        visit vehicles_path
        click_on 'EXU0F72'

        expect(page).to have_current_path(vehicle_path(vehicle))
        expect(page).to have_css('h1.page-title', text: 'Veículo EXU0F72')
        expect(dl_to_hash('#vehicle_data')).to eq(
          'Código' => '812',
          'Placa' => 'EXU0F72',
          'Categoria' => 'Caminhão / Cavalo',
          'Tipo do veículo' => 'TRUCK',
          'Marca' => 'VOLVO',
          'Modelo' => 'FH 540',
          'Ano fabricação/modelo' => '2021/2022',
          'Cor' => 'BRANCA',
          'Carroceria' => 'NAO APLICAVEL',
          'Rodado' => 'TRUCK',
          'Chassi' => '9BVRG40D5ME123456',
          'RENAVAM' => '01234567890',
          'ANTT' => '012345678',
          'Cidade' => 'IPATINGA/MG',
          'Situação na Atua' => 'Normal',
          'Gerenciamento de risco' => 'Liberado',
          'Validade do cadastro' => '31/03/2027',
        )
        expect(dl_to_hash('#ownership_data')).to eq(
          'Propriedade' => 'Agregado',
          'Proprietário' => 'JR TRANSPORTES LTDA 12.345.678/0001-90',
          'Motorista' => 'JOSE DA SILVA',
          'CPF do motorista' => '808.542.250-64',
          'CNH' => '604269044',
        )
      end

      scenario 'opens the driver of the vehicle' do
        visit vehicle_path(vehicle)
        click_on 'JOSE DA SILVA'

        expect(page).to have_current_path(driver_path(760))
      end

      scenario 'tells that the plate has no empty legs' do
        visit vehicle_path(vehicle)

        expect(EmptyLeg.count).to eq(0)
        expect(page).to have_text('Nenhum trecho rodado vazio por esta placa.')
      end

      context 'when the plate has empty legs' do
        let!(:betim) do
          create(:location, lookup_key: 'RUA DAS FLORES 10|BETIM|MG', street: 'RUA DAS FLORES 10', city: 'BETIM', state: 'MG',
                            precision_type: 'address')
        end
        let!(:ipatinga) { create(:location, lookup_key: '|IPATINGA|MG', city: 'IPATINGA', state: 'MG') }
        let!(:contagem) { create(:location, lookup_key: '|CONTAGEM|MG', city: 'CONTAGEM', state: 'MG') }

        before do
          create(:atua_manifest, tenant:, code: 41_200, plate: 'EXU0F72', trip_started_at: Time.zone.local(2026, 10, 3, 8))
          create(:atua_manifest, tenant:, code: 41_300, plate: 'EXU0F72', trip_started_at: nil, departure_on: Date.new(2026, 10, 7))
          create(:atua_manifest, tenant:, code: 41_400, plate: 'EXU0F72', trip_started_at: Time.zone.local(2026, 10, 9, 6))
          create(:empty_leg, tenant:, plate: 'EXU0F72', next_manifest_code: 41_200, origin: betim, destination: ipatinga,
                             distance_km: BigDecimal('217.44'), precision_type: 'city')
          create(:empty_leg, tenant:, plate: 'EXU0F72', next_manifest_code: 41_400, origin: ipatinga, destination: contagem,
                             distance_km: BigDecimal('48.2'), precision_type: 'city')
          create(:empty_leg, tenant:, plate: 'EXU0F72', next_manifest_code: 41_300, origin: contagem, destination: nil,
                             status_type: 'unlocated', distance_km: nil, precision_type: nil)
          create(:atua_manifest, tenant:, code: 41_500, plate: 'QWE1A23', trip_started_at: Time.zone.local(2026, 10, 4))
          create(:empty_leg, tenant:, plate: 'QWE1A23', next_manifest_code: 41_500)
          create(:atua_manifest, tenant: other_tenant, code: 41_600, plate: 'EXU0F72', trip_started_at: Time.zone.local(2026, 10, 5))
          create(:empty_leg, tenant: other_tenant, plate: 'EXU0F72', next_manifest_code: 41_600)
        end

        scenario 'lists every empty leg of the plate from the latest trip with the total' do
          visit vehicle_path(vehicle)

          expect(EmptyLeg.where(tenant:, plate: 'EXU0F72').count).to eq(3)
          expect(html_table_to_rows(table: find_by_id('vehicle_empty_legs'))).to eq(
            [
              ['Data da viagem', 'Saída (última entrega)', 'Chegada (coleta)', 'Precisão', 'KM vazio'],
              ['09/10/2026', 'IPATINGA/MG', 'CONTAGEM/MG', 'Centro da cidade', '48,20 km'],
              ['07/10/2026', 'CONTAGEM/MG', '-', '-', 'Endereço não localizado'],
              ['03/10/2026', 'RUA DAS FLORES 10 - BETIM/MG', 'IPATINGA/MG', 'Centro da cidade', '217,44 km'],
            ],
          )
          expect(page).to have_css('#vehicle_empty_legs_total', text: 'Total de KM vazio 265,64 km')
        end
      end

      scenario 'tells that the vehicle has no expenses' do
        visit vehicle_path(vehicle)

        expect(Atua::Expense.count).to eq(0)
        expect(page).to have_text('Nenhuma despesa vinculada a este veículo ou aos fretes dele.')
      end

      context 'when the vehicle and its freights have expenses' do
        let!(:transport_document) { create(:atua_transport_document, tenant:, number: '74512', vehicle_code: 812, plate: 'EXU0F72') }
        let!(:tire) do
          create(:atua_expense, tenant:, code: 590_301, posted_at: Time.zone.local(2026, 10, 5, 10), posted_on: Date.new(2026, 10, 5),
                                history_name: 'PNEUS', payee_name: 'PNEUS BH LTDA', plate: 'EXU0F72', total_cents: 200_000,
                                cost_object: vehicle)
        end
        let!(:toll) do
          create(:atua_expense, tenant:, code: 590_302, posted_at: Time.zone.local(2026, 10, 2, 7), posted_on: Date.new(2026, 10, 2),
                                history_name: 'PEDAGIO', payee_name: 'VIA 040', plate: 'EXU0F72', total_cents: 15_000,
                                cost_object: transport_document)
        end

        before do
          other_truck = create(:atua_vehicle, tenant:, code: 900, plate: 'UAV4A05')
          create(:atua_expense, tenant:, history_name: 'OUTRO CAMINHAO', plate: 'UAV4A05', cost_object: other_truck)
          create(:atua_expense, tenant:, history_name: 'REMOVIDA', plate: 'EXU0F72', cost_object: vehicle,
                                removed_from_atua_at: Time.current)
          create(:atua_expense, tenant:, history_name: 'ALUGUEL', plate: nil)
          stranger_truck = create(:atua_vehicle, tenant: other_tenant, code: 812, plate: 'EXU0F72')
          create(:atua_expense, tenant: other_tenant, history_name: 'ESTRANHA', plate: 'EXU0F72', cost_object: stranger_truck)
        end

        scenario 'lists its own expenses and the expenses of its freights with the totals' do
          visit vehicle_path(vehicle)

          expect(Atua::Expense.count).to eq(6)
          expect(html_table_to_rows(table: find_by_id('vehicle_expenses'))).to eq(
            [
              ['Histórico', 'Lançado em', 'Origem', 'Favorecido', 'Valor total'],
              ['PNEUS', '05/10/2026', 'Veículo', 'PNEUS BH LTDA', 'R$ 2.000,00'],
              ['PEDAGIO', '02/10/2026', 'CT-e 74512', 'VIA 040', 'R$ 150,00'],
            ],
          )
          expect(dl_to_hash('#vehicle_expenses_totals')).to eq(
            'Despesas diretas do veículo' => 'R$ 2.000,00',
            'Despesas dos fretes' => 'R$ 150,00',
            'Total de despesas' => 'R$ 2.150,00',
          )
        end

        scenario 'opens the expense and the freight of the expense' do
          visit vehicle_path(vehicle)

          expect(page).to have_link('CT-e 74512', href: transport_document_path(transport_document))

          click_on 'PNEUS'

          expect(page).to have_current_path(expense_path(tire))
        end
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:vehicle) { create(:atua_vehicle, tenant:, plate: 'EXU0F72', driver_code: 760, driver_name: 'JOSE DA SILVA') }

    before { login_as(operator, scope: :user) }

    context 'without access to the vehicles' do
      scenario 'is sent back with an access denied message' do
        visit vehicles_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end

      scenario 'cannot open a vehicle' do
        visit vehicle_path(vehicle)

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the vehicles' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'lists and opens the vehicles' do
        visit vehicles_path

        expect(Atua::Vehicle.count).to eq(1)
        expect(html_table_to_rows.size).to eq(2)

        click_on 'EXU0F72'

        expect(page).to have_current_path(vehicle_path(vehicle))
      end

      scenario 'does not link the driver without access to the drivers' do
        visit vehicle_path(vehicle)

        expect(page).to have_css('#ownership_data', text: 'JOSE DA SILVA')
        expect(page).to have_no_link('JOSE DA SILVA')
      end

      scenario 'does not show the expenses without access to them' do
        create(:atua_expense, tenant:, history_name: 'PNEUS', plate: 'EXU0F72', cost_object: vehicle)

        visit vehicle_path(vehicle)

        expect(Atua::Expense.count).to eq(1)
        expect(page).to have_no_text('Despesas do veículo')
        expect(page).to have_no_text('PNEUS')
      end
    end
  end

  context 'on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:vehicle) { create(:atua_vehicle, tenant:, plate: 'EXU0F72') }

    before do
      login_as(admin, scope: :user)
      use_mobile_screen
    end

    scenario 'keeps only the essential columns without horizontal scroll' do
      visit vehicles_path

      expect(page).to have_link('EXU0F72')
      expect(page).to have_no_css('th', text: 'Categoria')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end

    context 'when the plate has empty legs' do
      let!(:location) do
        create(:location, lookup_key: 'AVENIDA DAS INDUSTRIAS 1500|SANTANA DE PARNAIBA|SP', street: 'AVENIDA DAS INDUSTRIAS 1500',
                          city: 'SANTANA DE PARNAIBA', state: 'SP')
      end

      before do
        create(:atua_manifest, tenant:, code: 41_200, plate: 'EXU0F72', trip_started_at: Time.zone.local(2026, 10, 3, 8))
        create(:empty_leg, tenant:, plate: 'EXU0F72', next_manifest_code: 41_200, origin: location, destination: location)
      end

      scenario 'keeps only the trip date and the distance without horizontal scroll' do
        visit vehicle_path(vehicle)

        expect(page).to have_css('#vehicle_empty_legs td', text: '48,20 km')
        expect(page).to have_no_css('#vehicle_empty_legs th', text: 'Saída (última entrega)')
        expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      end
    end

    context 'when the vehicle has expenses' do
      let!(:expenses_resource) { create(:resource, name: 'Despesas', slug: 'expenses', writable: false) }

      before { create(:atua_expense, tenant:, history_name: 'PNEUS', plate: 'EXU0F72', total_cents: 200_000, cost_object: vehicle) }

      scenario 'keeps only the history and the total of the expenses without horizontal scroll' do
        visit vehicle_path(vehicle)

        expect(page).to have_css('#vehicle_expenses td', text: 'R$ 2.000,00')
        expect(page).to have_no_css('#vehicle_expenses th', text: 'Origem')
        expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      end
    end
  end
end
