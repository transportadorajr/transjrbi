require 'rails_helper'

describe 'Export shortcuts', flipper: { export_summary: :tenant } do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Atalhos da exportação', slug: 'export_shortcuts') }
  let!(:arcelor) { create(:customer_group, tenant:, name: 'ARCELORMITTAL') }
  let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
  let!(:juiz_de_fora) { create(:export_plant, tenant:, customer_group: arcelor, name: 'Juiz de Fora', cities: ['JUIZ DE FORA']) }
  let!(:ipatinga) { create(:export_plant, tenant:, customer_group: usiminas, name: 'Ipatinga', cities: ['IPATINGA']) }

  context 'without a signed in user' do
    scenario 'redirects the listing to the login screen' do
      visit export_shortcuts_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are no shortcuts' do
      scenario 'shows the empty state message' do
        visit export_shortcuts_path

        expect(ExportShortcut.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are shortcuts' do
      let!(:paraguay) do
        create(:export_shortcut, tenant:, name: 'Arcelor Juiz de Fora → Paraguai', customer_group: arcelor, export_plant_ids: [juiz_de_fora.id],
                                 countries: %w[paraguay argentina], position: 1)
      end
      let!(:everything) { create(:export_shortcut, tenant:, name: 'Toda a exportação', position: 0, activated_at: nil) }
      let!(:stranger) { create(:export_shortcut, tenant: other_tenant, name: 'ATALHO DE OUTRA') }

      scenario 'lists the shortcuts of the tenant from the registrations menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Atalhos da exportação'
        end

        expect(page).to have_current_path(export_shortcuts_path)
        expect(ExportShortcut.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Cliente', 'Plantas de origem', 'Países de destino', 'Ordem', 'Status', 'Ações'],
            ['Toda a exportação', 'Todos os clientes', 'Todas as plantas', 'Todos os países', '0', 'Inativo',
             'Opções Visualizar Alterar Ativar Excluir'],
            ['Arcelor Juiz de Fora → Paraguai', 'ARCELORMITTAL', 'Juiz de Fora', 'Paraguai, Argentina', '1', 'Ativo',
             'Opções Visualizar Alterar Inativar Excluir'],
          ],
        )
        expect(page).to have_css('.counter-card', text: "Total de atalhos\n2")
        expect(page).to have_no_text('ATALHO DE OUTRA')
      end

      scenario 'shows every detail of a shortcut' do
        visit export_shortcut_path(paraguay)

        expect(dl_to_hash('#export_shortcut_data')).to eq(
          'Nome' => 'Arcelor Juiz de Fora → Paraguai',
          'Cliente' => 'ARCELORMITTAL',
          'Plantas de origem' => 'Juiz de Fora',
          'Países de destino' => 'Paraguai, Argentina',
          'Ordem' => '1',
          'Status' => 'Ativo',
        )
        expect(page).to have_no_link('Ver no resumo')
      end

      scenario 'deactivates a shortcut' do
        page.driver.submit :patch, deactivate_export_shortcut_path(paraguay), {}

        expect(page).to have_text('Registro inativado com sucesso.')
        expect(paraguay.reload).not_to be_activated
      end

      scenario 'removes a shortcut' do
        expect { page.driver.submit :delete, export_shortcut_path(paraguay), {} }.to change(ExportShortcut, :count).by(-1)

        expect(page).to have_text('Atalho excluído com sucesso.')
      end

      scenario 'does not open a shortcut of another tenant' do
        visit export_shortcut_path(stranger)

        expect(page.status_code).to eq(404)
      end
    end

    scenario 'creates a shortcut with plants and countries' do
      visit export_shortcuts_path
      click_on 'Novo Atalho'

      fill_in 'Nome', with: 'Usiminas Ipatinga → Argentina'
      fill_in 'Ordem', with: '2'
      select 'USIMINAS', from: 'Cliente'
      check 'Ipatinga (USIMINAS)'
      check 'Argentina'

      expect { click_on 'Cadastrar Atalho' }.to change(ExportShortcut, :count).by(1)

      shortcut = ExportShortcut.last
      expect(page).to have_current_path(export_shortcut_path(shortcut))
      expect(page).to have_text('Atalho cadastrado com sucesso.')
      expect(shortcut).to have_attributes(tenant:, name: 'Usiminas Ipatinga → Argentina', customer_group: usiminas, export_plant_ids: [ipatinga.id],
                                          countries: ['argentina'], position: 2)
      expect(shortcut).to be_activated
    end

    scenario 'shows the error of a plant of another customer' do
      visit new_export_shortcut_path

      fill_in 'Nome', with: 'Arcelor'
      select 'ARCELORMITTAL', from: 'Cliente'
      check 'Ipatinga (USIMINAS)'

      expect { click_on 'Cadastrar Atalho' }.not_to change(ExportShortcut, :count)

      expect(page).to have_text('Plantas de origem devem ser plantas ativas desta empresa e do cliente escolhido')
    end

    scenario 'updates a shortcut' do
      shortcut = create(:export_shortcut, tenant:, name: 'Arcelor', countries: ['paraguay'])
      visit edit_export_shortcut_path(shortcut)

      check 'País não identificado'
      expect { click_on 'Salvar Alterações' }.not_to change(ExportShortcut, :count)

      expect(page).to have_text('Atalho atualizado com sucesso.')
      expect(shortcut.reload.countries).to eq(%w[paraguay unknown])
    end
  end

  context 'when an operator with read access is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:access) { create(:access, user: operator, resource:, reads: true) }
    let!(:shortcut) { create(:export_shortcut, tenant:, name: 'Arcelor') }

    before { login_as(operator, scope: :user) }

    scenario 'lists the shortcuts without the management actions' do
      visit export_shortcuts_path

      expect(html_table_to_rows.last).to eq(['Arcelor', 'Todos os clientes', 'Todas as plantas', 'Todos os países', '0', 'Ativo', ''])
      expect(page).to have_no_link('Novo Atalho')
    end

    scenario 'cannot change a shortcut through a forged request' do
      page.driver.submit :patch, export_shortcut_path(shortcut), { export_shortcut: { name: 'Outro' } }

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      expect(shortcut.reload.name).to eq('Arcelor')
    end
  end

  context 'when the export summary is off for the tenant' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before do
      Flipper.disable(:export_summary)
      login_as(owner, scope: :user)
    end

    scenario 'answers not found' do
      visit export_shortcuts_path

      expect(page.status_code).to eq(404)
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }
    let!(:shortcut) { create(:export_shortcut, tenant:, name: 'Arcelor') }

    before { login_as(owner, scope: :user) }

    scenario 'keeps the essential columns and does not scroll sideways' do
      visit export_shortcuts_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'NOME')
      expect(page).to have_no_css('th', text: 'PAÍSES DE DESTINO')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
