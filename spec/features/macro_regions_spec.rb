require 'rails_helper'

describe 'Macro regions' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Macro regiões', slug: 'macro_regions') }

  context 'without a signed in user' do
    scenario 'redirects the listing to the login screen' do
      visit macro_regions_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'does not create a region' do
      expect do
        page.driver.submit :post, macro_regions_path, { macro_region: { name: 'GRANDE BH', state: 'MG', cities: 'Betim' } }
      end.not_to change(MacroRegion, :count)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when there are no regions' do
      scenario 'shows the empty state message' do
        visit macro_regions_path

        expect(MacroRegion.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are regions' do
      let!(:vale_do_aco) { create(:macro_region, tenant:) }
      let!(:sao_paulo) { create(:macro_region, :sao_paulo, tenant:) }
      let!(:interior) { create(:macro_region, :interior_sp, tenant:) }
      let!(:stranger_region) { create(:macro_region, tenant: other_tenant, name: 'REGIAO DE OUTRA') }

      scenario 'lists the regions of the tenant from the registrations menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Macro regiões'
        end

        expect(page).to have_current_path(macro_regions_path)
        expect(MacroRegion.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            %w[Nome UF Abrangência Ações],
            ['VALE DO AÇO/MG', 'MG', '3 cidades', 'Opções Visualizar Alterar Excluir'],
            ['INTERIOR SP', 'SP', 'Restante de SP', 'Opções Visualizar Alterar Excluir'],
            ['SAO PAULO REGIAO METROCAPITAL', 'SP', '3 cidades', 'Opções Visualizar Alterar Excluir'],
          ],
        )
        expect(page).to have_link('Nova Macro Região', href: new_macro_region_path)
        expect(page).to have_no_text('REGIAO DE OUTRA')
      end

      scenario 'filters the regions by name' do
        visit macro_regions_path
        fill_in 'Nome da macro região', with: 'paulo'
        click_on 'Aplicar Filtros'

        expect(MacroRegion.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            %w[Nome UF Abrangência Ações],
            ['SAO PAULO REGIAO METROCAPITAL', 'SP', '3 cidades', 'Opções Visualizar Alterar Excluir'],
          ],
        )
      end

      context 'when the region has documents' do
        before do
          create_list(:atua_transport_document, 2, tenant:, origin_city: 'IPATINGA', origin_state: 'MG')
          MacroRegions::AssignCommand.call(tenant)
        end

        scenario 'shows the region with its cities and documents' do
          visit macro_regions_path
          click_on 'VALE DO AÇO/MG'

          expect(page).to have_current_path(macro_region_path(vale_do_aco))
          expect(page).to have_css('h1.page-title', text: 'VALE DO AÇO/MG')
          expect(dl_to_hash('#macro_region_data')).to eq(
            'Nome' => vale_do_aco.name,
            'UF' => vale_do_aco.state,
            'Abrangência' => '3 cidades',
            'Cidades' => 'Ipatinga, Coronel Fabriciano, Timóteo',
            'CT-es com origem na região' => '2',
          )
        end
      end

      scenario 'shows that a remaining state region covers the other cities of the state' do
        visit macro_region_path(interior)

        expect(dl_to_hash('#macro_region_data')).to eq(
          'Nome' => interior.name,
          'UF' => interior.state,
          'Abrangência' => 'Restante de SP',
          'Cidades' => 'Todas as cidades de SP que não estão em outra macro região',
          'CT-es com origem na região' => '0',
        )
      end

      scenario 'does not show a region of another tenant' do
        visit macro_region_path(stranger_region)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when creating a region' do
      let!(:betim_document) { create(:atua_transport_document, tenant:, origin_city: 'BETIM', origin_state: 'MG') }

      scenario 'creates a region with its cities and assigns the documents of its cities' do
        visit macro_regions_path
        click_on 'Nova Macro Região'
        fill_in 'Nome', with: 'GRANDE BH'
        fill_in 'UF', with: 'mg'
        fill_in 'Cidades', with: "Belo Horizonte\nBetim\nContagem"

        expect { click_on 'Cadastrar Macro Região' }.to change(MacroRegion, :count).by(1)

        macro_region = MacroRegion.last
        expect(page).to have_current_path(macro_region_path(macro_region))
        expect(page).to have_text('Macro região cadastrada com sucesso.')
        expect(macro_region).to have_attributes(tenant:, name: 'GRANDE BH', state: 'MG', cities: ['Belo Horizonte', 'Betim', 'Contagem'],
                                                remaining_state: false)
        expect(betim_document.reload.origin_macro_region).to eq(macro_region)
      end

      scenario 'creates a region with the remaining cities of the state' do
        visit new_macro_region_path
        fill_in 'Nome', with: 'INTERIOR MG'
        fill_in 'UF', with: 'MG'
        check 'Abrange o restante do estado'

        expect { click_on 'Cadastrar Macro Região' }.to change(MacroRegion, :count).by(1)

        expect(MacroRegion.last).to have_attributes(name: 'INTERIOR MG', state: 'MG', cities: [], remaining_state: true)
        expect(betim_document.reload.origin_macro_region).to eq(MacroRegion.last)
      end

      scenario 'shows the errors of the required fields' do
        visit new_macro_region_path

        expect { click_on 'Cadastrar Macro Região' }.not_to change(MacroRegion, :count)

        expect(page).to have_text('Nome não pode ficar em branco')
        expect(page).to have_text('Cidades não pode ficar em branco')
      end

      context 'when a city is already in another region of the state' do
        let!(:vale_do_aco) { create(:macro_region, tenant:) }

        scenario 'shows the validation message' do
          visit new_macro_region_path
          fill_in 'Nome', with: 'LESTE MG'
          fill_in 'UF', with: 'MG'
          fill_in 'Cidades', with: "Ipatinga\nGovernador Valadares"

          expect { click_on 'Cadastrar Macro Região' }.not_to change(MacroRegion, :count)

          expect(page).to have_text('Cidades Ipatinga já estão em outra macro região desta UF')
        end
      end
    end

    context 'when editing a region' do
      let!(:macro_region) { create(:macro_region, tenant:) }
      let!(:belo_oriente_document) { create(:atua_transport_document, tenant:, origin_city: 'BELO ORIENTE', origin_state: 'MG') }

      scenario 'updates the region and assigns the documents of the new cities' do
        visit macro_regions_path
        within("#macro_region_#{macro_region.id} .inline-actions") { click_on 'Alterar' }

        expect(page).to have_current_path(edit_macro_region_path(macro_region))
        expect(page).to have_field('Cidades', with: "Ipatinga\nCoronel Fabriciano\nTimóteo")

        fill_in 'Cidades', with: "Ipatinga\nCoronel Fabriciano\nTimóteo\nBelo Oriente"

        expect { click_on 'Salvar Alterações' }.not_to change(MacroRegion, :count)

        expect(page).to have_current_path(macro_region_path(macro_region))
        expect(page).to have_text('Macro região atualizada com sucesso.')
        expect(macro_region.reload.cities).to eq(['Ipatinga', 'Coronel Fabriciano', 'Timóteo', 'Belo Oriente'])
        expect(belo_oriente_document.reload.origin_macro_region).to eq(macro_region)
      end
    end

    context 'when removing a region' do
      let!(:macro_region) { create(:macro_region, tenant:) }
      let!(:ipatinga_document) { create(:atua_transport_document, tenant:, origin_city: 'IPATINGA', origin_state: 'MG') }

      before { MacroRegions::AssignCommand.call(tenant) }

      scenario 'removes the region and moves its documents to the other regions' do
        visit macro_regions_path

        expect(page).to have_css(
          "#macro_region_#{macro_region.id} a[data-turbo-confirm='Tem certeza que deseja excluir esta macro região? " \
          "Os CT-es dela passam para Outras Regiões.']",
        )

        expect { page.driver.submit :delete, macro_region_path(macro_region), {} }.to change(MacroRegion, :count).by(-1)

        expect(page).to have_current_path(macro_regions_path)
        expect(page).to have_text('Macro região excluída com sucesso.')
        expect(ipatinga_document.reload.origin_macro_region).to be_nil
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:macro_region) { create(:macro_region, tenant:) }

    before { login_as(operator, scope: :user) }

    context 'without access to the regions' do
      scenario 'is sent back with an access denied message' do
        visit macro_regions_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the regions' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'lists the regions without the management actions' do
        visit macro_regions_path

        expect(MacroRegion.count).to eq(1)
        expect(html_table_to_rows).to eq(
          [
            %w[Nome UF Abrangência Ações],
            ['VALE DO AÇO/MG', 'MG', '3 cidades', ''],
          ],
        )
        expect(page).to have_no_link('Nova Macro Região')

        click_on 'VALE DO AÇO/MG'

        expect(page).to have_no_link('Alterar')
      end

      scenario 'cannot change a region through a forged request' do
        page.driver.submit :patch, macro_region_path(macro_region), { macro_region: { name: 'OUTRA' } }

        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
        expect(macro_region.reload.name).to eq('VALE DO AÇO/MG')
      end
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:macro_region) { create(:macro_region, tenant:) }

    before { login_as(admin, scope: :user) }

    scenario 'keeps the essential columns and collapses the actions into a menu' do
      visit macro_regions_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'NOME')
      expect(page).to have_no_css('th', text: 'ABRANGÊNCIA')

      within("#macro_region_#{macro_region.id}") do
        expect(page).to have_no_css('.inline-actions')
        click_button 'Opções'
        click_on 'Alterar'
      end

      expect(page).to have_current_path(edit_macro_region_path(macro_region))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
