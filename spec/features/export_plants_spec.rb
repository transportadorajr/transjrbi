require 'rails_helper'

describe 'Export plants', flipper: { export_summary: :tenant } do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Plantas de exportação', slug: 'export_plants') }
  let!(:arcelor) { create(:customer_group, tenant:, name: 'ARCELORMITTAL', terms: ['ARCELOR']) }
  let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS', terms: ['USIMINAS']) }

  context 'without a signed in user' do
    scenario 'redirects the listing to the login screen' do
      visit export_plants_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'does not create a plant' do
      expect do
        page.driver.submit :post, export_plants_path, { export_plant: { name: 'Ipatinga' } }
      end.not_to change(ExportPlant, :count)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are no plants' do
      scenario 'shows the empty state message' do
        visit export_plants_path

        expect(ExportPlant.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are plants' do
      let!(:juiz_de_fora) { create(:export_plant, tenant:, customer_group: arcelor, name: 'Juiz de Fora', cities: ['JUIZ DE FORA']) }
      let!(:sul_fluminense) { create(:export_plant, tenant:, customer_group: arcelor, name: 'Sul Fluminense', cities: ['RESENDE', 'BARRA MANSA']) }
      let!(:ipatinga) { create(:export_plant, tenant:, customer_group: usiminas, name: 'Ipatinga', cities: ['IPATINGA'], activated_at: nil) }
      let!(:stranger_plant) { create(:export_plant, tenant: other_tenant, name: 'PLANTA DE OUTRA') }

      scenario 'lists the plants of the tenant from the registrations menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Plantas de exportação'
        end

        expect(page).to have_current_path(export_plants_path)
        expect(ExportPlant.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Grupo de clientes', 'Cidades de origem', 'Status', 'Ações'],
            ['Juiz de Fora', 'ARCELORMITTAL', 'JUIZ DE FORA', 'Ativa', 'Opções Visualizar Alterar Inativar Excluir'],
            ['Sul Fluminense', 'ARCELORMITTAL', 'RESENDE, BARRA MANSA', 'Ativa', 'Opções Visualizar Alterar Inativar Excluir'],
            ['Ipatinga', 'USIMINAS', 'IPATINGA', 'Inativa', 'Opções Visualizar Alterar Ativar Excluir'],
          ],
        )
        expect(page).to have_css('.counter-card', text: "Total de plantas\n3")
        expect(page).to have_css('.counter-card', text: "Plantas ativas\n2")
        expect(page).to have_css('.counter-card', text: "Plantas inativas\n1")
        expect(page).to have_link('Nova Planta', href: new_export_plant_path)
        expect(page).to have_no_text('PLANTA DE OUTRA')
      end

      scenario 'filters the plants by name, group and status' do
        visit export_plants_path(name: 'fluminense', customer_group_id: arcelor.id, status: 'active')

        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Grupo de clientes', 'Cidades de origem', 'Status', 'Ações'],
            ['Sul Fluminense', 'ARCELORMITTAL', 'RESENDE, BARRA MANSA', 'Ativa', 'Opções Visualizar Alterar Inativar Excluir'],
          ],
        )
      end

      scenario 'shows every detail of a plant' do
        visit export_plants_path
        click_on 'Sul Fluminense'

        expect(page).to have_current_path(export_plant_path(sul_fluminense))
        expect(page).to have_css('h1.page-title', text: 'Sul Fluminense')
        expect(dl_to_hash('#export_plant_data')).to eq(
          'Nome' => 'Sul Fluminense',
          'Grupo de clientes' => 'ARCELORMITTAL',
          'Cidades de origem' => 'RESENDE, BARRA MANSA',
          'Status' => 'Ativa',
        )
      end

      scenario 'deactivates an active plant from the listing' do
        visit export_plants_path

        expect { page.driver.submit :patch, deactivate_export_plant_path(juiz_de_fora), {} }.not_to change(ExportPlant, :count)

        expect(page).to have_text('Registro inativado com sucesso.')
        expect(juiz_de_fora.reload).not_to be_activated
      end

      scenario 'does not open a plant of another tenant' do
        visit export_plant_path(stranger_plant)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when creating a plant' do
      scenario 'creates a plant that joins several cities' do
        visit export_plants_path
        click_on 'Nova Planta'

        select 'ARCELORMITTAL', from: 'Grupo de clientes'
        fill_in 'Nome', with: 'Sul Fluminense'
        fill_in 'Cidades de origem', with: "Resende\nBarra Mansa"

        expect { click_on 'Cadastrar Planta' }.to change(ExportPlant, :count).by(1)

        plant = ExportPlant.last
        expect(page).to have_current_path(export_plant_path(plant))
        expect(page).to have_text('Planta cadastrada com sucesso.')
        expect(plant).to have_attributes(tenant:, customer_group: arcelor, name: 'Sul Fluminense', cities: ['Resende', 'Barra Mansa'])
        expect(plant).to be_activated
      end

      scenario 'shows the errors of the required fields' do
        visit new_export_plant_path

        expect { click_on 'Cadastrar Planta' }.not_to change(ExportPlant, :count)

        expect(page).to have_text('Grupo de clientes não pode ficar em branco')
        expect(page).to have_text('Cidades de origem não pode ficar em branco')
      end
    end

    context 'when editing a plant' do
      let!(:plant) { create(:export_plant, tenant:, customer_group: usiminas, name: 'Cubatão', cities: ['CUBATAO']) }
      let!(:cds) { create(:export_plant, tenant:, customer_group: usiminas, name: 'CD Santo André', cities: ['SANTO ANDRE']) }

      scenario 'updates the plant' do
        visit export_plant_path(plant)
        click_on 'Alterar'

        fill_in 'Nome', with: 'Usina de Cubatão'
        expect { click_on 'Salvar Alterações' }.not_to change(ExportPlant, :count)

        expect(page).to have_text('Planta atualizada com sucesso.')
        expect(plant.reload).to have_attributes(name: 'Usina de Cubatão', cities: ['CUBATAO'])
      end

      scenario 'does not take a city of another active plant of the group' do
        visit edit_export_plant_path(plant)

        fill_in 'Cidades de origem', with: "CUBATAO\nSanto André"
        click_on 'Salvar Alterações'

        expect(page).to have_text('Cidades de origem Santo André já estão em outra planta ativa deste grupo')
        expect(plant.reload.cities).to eq(['CUBATAO'])
      end
    end

    context 'when removing a plant' do
      let!(:plant) { create(:export_plant, tenant:, customer_group: usiminas, name: 'Cubatão') }

      scenario 'removes the plant' do
        visit export_plants_path

        expect { page.driver.submit :delete, export_plant_path(plant), {} }.to change(ExportPlant, :count).by(-1)

        expect(page).to have_text('Planta excluída com sucesso.')
      end
    end
  end

  context 'when the export summary is off for the tenant' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before do
      Flipper.disable(:export_summary)
      login_as(owner, scope: :user)
    end

    scenario 'hides the menu and answers not found' do
      visit root_path

      expect(page).to have_css('.sidebar-desktop')
      expect(page).to have_no_link('Plantas de exportação')

      visit export_plants_path

      expect(page.status_code).to eq(404)
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:plant) { create(:export_plant, tenant:, customer_group: arcelor, name: 'Juiz de Fora', cities: ['JUIZ DE FORA']) }

    before { login_as(operator, scope: :user) }

    context 'without access to the plants' do
      scenario 'is sent back with an access denied message' do
        visit export_plants_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the plants' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'lists the plants without the management actions' do
        visit export_plants_path

        expect(ExportPlant.count).to eq(1)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Grupo de clientes', 'Cidades de origem', 'Status', 'Ações'],
            ['Juiz de Fora', 'ARCELORMITTAL', 'JUIZ DE FORA', 'Ativa', ''],
          ],
        )
        expect(page).to have_no_link('Nova Planta')
      end

      scenario 'cannot change a plant through a forged request' do
        page.driver.submit :patch, export_plant_path(plant), { export_plant: { name: 'Outra' } }

        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
        expect(plant.reload.name).to eq('Juiz de Fora')
      end
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }
    let!(:plant) { create(:export_plant, tenant:, customer_group: arcelor, name: 'Juiz de Fora', cities: ['JUIZ DE FORA']) }

    before { login_as(owner, scope: :user) }

    scenario 'keeps the essential columns and collapses the actions into a menu' do
      visit export_plants_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'NOME')
      expect(page).to have_no_css('th', text: 'CIDADES DE ORIGEM')

      within("#export_plant_#{plant.id}") do
        expect(page).to have_no_css('.inline-actions')
        click_button 'Opções'
        click_on 'Alterar'
      end

      expect(page).to have_current_path(edit_export_plant_path(plant))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
