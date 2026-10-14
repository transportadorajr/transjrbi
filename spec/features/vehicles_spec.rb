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
  end
end
