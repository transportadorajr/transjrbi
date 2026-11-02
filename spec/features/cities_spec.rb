require 'rails_helper'

describe 'Cities' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Cidades', slug: 'cities') }

  context 'without a signed in user' do
    scenario 'redirects the listing to the login screen' do
      visit cities_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'does not create a city' do
      expect do
        page.driver.submit :post, cities_path, { city: { name: 'Betim', state: 'MG' } }
      end.not_to change(City, :count)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when there are no cities' do
      scenario 'shows the empty state message' do
        visit cities_path

        expect(City.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are cities' do
      let!(:vale_do_aco) { create(:macro_region, tenant:, city_names: %w[Ipatinga Timóteo]) }
      let!(:cubatao) { create(:city, tenant:, name: 'Cubatão', state: 'SP') }
      let!(:stranger_city) { create(:city, tenant: other_tenant, name: 'Cidade de Outra', state: 'MG') }

      scenario 'lists the cities of the tenant from the registrations menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Cidades'
        end

        expect(page).to have_current_path(cities_path)
        expect(City.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'UF', 'Macro região', 'Ações'],
            ['Ipatinga', 'MG', 'VALE DO AÇO/MG', 'Opções Visualizar Alterar Excluir'],
            ['Timóteo', 'MG', 'VALE DO AÇO/MG', 'Opções Visualizar Alterar Excluir'],
            ['Cubatão', 'SP', 'Sem macro região', 'Opções Visualizar Alterar Excluir'],
          ],
        )
        expect(page).to have_link('Nova Cidade', href: new_city_path)
        expect(page).to have_no_text('Cidade de Outra')
      end

      scenario 'filters the cities by name, state and macro region' do
        visit cities_path
        fill_in 'Nome da cidade', with: 'tim'
        fill_in 'UF', with: 'mg'
        select 'VALE DO AÇO/MG (MG)', from: 'Macro região'
        click_on 'Aplicar Filtros'

        expect(City.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'UF', 'Macro região', 'Ações'],
            ['Timóteo', 'MG', 'VALE DO AÇO/MG', 'Opções Visualizar Alterar Excluir'],
          ],
        )
      end

      scenario 'filters the cities without a macro region' do
        visit cities_path
        select 'Sem macro região', from: 'Macro região'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'UF', 'Macro região', 'Ações'],
            ['Cubatão', 'SP', 'Sem macro região', 'Opções Visualizar Alterar Excluir'],
          ],
        )
      end

      scenario 'shows the city' do
        ipatinga = vale_do_aco.cities.find_by!(name: 'Ipatinga')

        visit cities_path
        click_on 'Ipatinga'

        expect(page).to have_current_path(city_path(ipatinga))
        expect(page).to have_css('h1.page-title', text: 'Ipatinga')
        expect(dl_to_hash('#city_data')).to eq(
          'Nome' => ipatinga.name,
          'UF' => ipatinga.state,
          'Macro região' => ipatinga.macro_region.name,
        )
      end

      scenario 'does not show a city of another tenant' do
        visit city_path(stranger_city)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when creating a city' do
      let!(:vale_do_aco) { create(:macro_region, tenant:) }
      let!(:interior) { create(:macro_region, :interior_sp, tenant:) }
      let!(:belo_oriente_document) { create(:atua_transport_document, tenant:, origin_city: 'BELO ORIENTE', origin_state: 'MG') }

      scenario 'creates a city in a macro region and assigns the documents of the city' do
        visit cities_path
        click_on 'Nova Cidade'

        expect(page).to have_select('Macro região', options: ['Sem macro região', 'VALE DO AÇO/MG (MG)'])

        fill_in 'Nome', with: 'Belo Oriente'
        fill_in 'UF', with: 'mg'
        select 'VALE DO AÇO/MG (MG)', from: 'Macro região'

        expect { click_on 'Cadastrar Cidade' }.to change(City, :count).by(1)

        city = City.last
        expect(page).to have_current_path(city_path(city))
        expect(page).to have_text('Cidade cadastrada com sucesso.')
        expect(city).to have_attributes(tenant:, name: 'Belo Oriente', state: 'MG', macro_region: vale_do_aco)
        expect(belo_oriente_document.reload.origin_macro_region).to eq(vale_do_aco)
      end

      scenario 'shows the errors of the form' do
        visit new_city_path
        fill_in 'Nome', with: 'TIMOTEO'
        fill_in 'UF', with: 'MG'

        expect { click_on 'Cadastrar Cidade' }.not_to change(City, :count)

        expect(page).to have_text('Nome já está cadastrada nesta UF')
      end

      scenario 'rejects a macro region of another state' do
        visit new_city_path
        fill_in 'Nome', with: 'Cubatão'
        fill_in 'UF', with: 'SP'
        select 'VALE DO AÇO/MG (MG)', from: 'Macro região'

        expect { click_on 'Cadastrar Cidade' }.not_to change(City, :count)

        expect(page).to have_text('Macro região é de outra UF (MG)')
      end
    end

    context 'when editing a city' do
      let!(:vale_do_aco) { create(:macro_region, tenant:) }
      let!(:ipatinga) { vale_do_aco.cities.find_by!(name: 'Ipatinga') }
      let!(:ipatinga_document) { create(:atua_transport_document, tenant:, origin_city: 'IPATINGA', origin_state: 'MG') }

      before { MacroRegions::AssignCommand.call(tenant) }

      scenario 'takes the city out of its macro region and moves its documents to Others' do
        visit cities_path
        within("#city_#{ipatinga.id} .inline-actions") { click_on 'Alterar' }

        expect(page).to have_current_path(edit_city_path(ipatinga))
        expect(page).to have_field('Nome', with: 'Ipatinga')
        expect(page).to have_select('Macro região', selected: 'VALE DO AÇO/MG (MG)')

        select 'Sem macro região', from: 'Macro região'

        expect { click_on 'Salvar Alterações' }.not_to change(City, :count)

        expect(page).to have_current_path(city_path(ipatinga))
        expect(page).to have_text('Cidade atualizada com sucesso.')
        expect(ipatinga.reload).to have_attributes(name: 'Ipatinga', state: 'MG', macro_region: nil)
        expect(ipatinga_document.reload.origin_macro_region).to be_nil
      end
    end

    context 'when removing a city' do
      let!(:vale_do_aco) { create(:macro_region, tenant:) }
      let!(:ipatinga) { vale_do_aco.cities.find_by!(name: 'Ipatinga') }
      let!(:ipatinga_document) { create(:atua_transport_document, tenant:, origin_city: 'IPATINGA', origin_state: 'MG') }

      before { MacroRegions::AssignCommand.call(tenant) }

      scenario 'removes the city and moves its documents out of the region' do
        visit cities_path

        expect(page).to have_css(
          "#city_#{ipatinga.id} a[data-turbo-confirm='Tem certeza que deseja excluir esta cidade? " \
          "Os CT-es dela passam para outra macro região da UF ou para Outras Regiões.']",
        )

        expect { page.driver.submit :delete, city_path(ipatinga), {} }.to change(City, :count).by(-1)

        expect(page).to have_current_path(cities_path)
        expect(page).to have_text('Cidade excluída com sucesso.')
        expect(ipatinga_document.reload.origin_macro_region).to be_nil
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:city) { create(:city, tenant:) }

    before { login_as(operator, scope: :user) }

    context 'without access to the cities' do
      scenario 'is sent back with an access denied message' do
        visit cities_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the cities' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'lists the cities without the management actions' do
        visit cities_path

        expect(City.count).to eq(1)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'UF', 'Macro região', 'Ações'],
            ['Ipatinga', 'MG', 'Sem macro região', ''],
          ],
        )
        expect(page).to have_no_link('Nova Cidade')

        click_on 'Ipatinga'

        expect(page).to have_no_link('Alterar')
      end

      scenario 'cannot change a city through a forged request' do
        page.driver.submit :patch, city_path(city), { city: { name: 'Outra' } }

        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
        expect(city.reload.name).to eq('Ipatinga')
      end
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:city) { create(:city, tenant:) }

    before { login_as(admin, scope: :user) }

    scenario 'keeps the essential columns and collapses the actions into a menu' do
      visit cities_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'NOME')
      expect(page).to have_no_css('th', text: 'MACRO REGIÃO')

      within("#city_#{city.id}") do
        expect(page).to have_no_css('.inline-actions')
        click_button 'Opções'
        click_on 'Alterar'
      end

      expect(page).to have_current_path(edit_city_path(city))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
