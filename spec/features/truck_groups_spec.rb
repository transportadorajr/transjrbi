require 'rails_helper'

describe 'Truck groups' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Grupos de caminhões', slug: 'truck_groups') }

  context 'without a signed in user' do
    scenario 'redirects the listing to the login screen' do
      visit truck_groups_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'does not create a group' do
      expect do
        page.driver.submit :post, truck_groups_path, { truck_group: { name: 'Rodotrem', axles: ['9'], fuel_percentage: '35' } }
      end.not_to change(TruckGroup, :count)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when there are no groups' do
      scenario 'shows the empty state message' do
        visit truck_groups_path

        expect(TruckGroup.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are groups' do
      let!(:rodotrem) { create(:truck_group, tenant:, name: 'Rodotrem', axles: [9], fuel_percentage: BigDecimal('32.5')) }
      let!(:quarto_eixo) { create(:truck_group, tenant:, name: 'Quarto eixo', axles: [7, 8], fuel_percentage: 0) }
      let!(:ls) { create(:truck_group, :ls, tenant:, activated_at: nil) }
      let!(:stranger_group) { create(:truck_group, tenant: other_tenant, name: 'GRUPO DE OUTRA') }

      scenario 'lists the groups of the tenant from the registrations menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Grupos de caminhões'
        end

        expect(page).to have_current_path(truck_groups_path)
        expect(TruckGroup.count).to eq(4)
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(
          ['Total de grupos 3', 'Grupos ativos 2', 'Grupos inativos 1'],
        )
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Quantidades de eixos', 'Combustível sobre o frete', 'Status', 'Ações'],
            ['LS', '6 eixos', '30%', 'Inativo', 'Opções Visualizar Alterar Excluir'],
            ['Quarto eixo', '7 e 8 eixos', '0%', 'Ativo', 'Opções Visualizar Alterar Excluir'],
            ['Rodotrem', '9 eixos', '32,5%', 'Ativo', 'Opções Visualizar Alterar Excluir'],
          ],
        )
        expect(page).to have_link('Novo Grupo', href: new_truck_group_path)
        expect(page).to have_no_text('GRUPO DE OUTRA')
      end

      scenario 'filters the groups by name and status' do
        visit truck_groups_path
        fill_in 'Nome do grupo', with: 'eixo'
        click_on 'Aplicar Filtros'

        expect(TruckGroup.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Quantidades de eixos', 'Combustível sobre o frete', 'Status', 'Ações'],
            ['Quarto eixo', '7 e 8 eixos', '0%', 'Ativo', 'Opções Visualizar Alterar Excluir'],
          ],
        )

        visit truck_groups_path
        select 'Inativo', from: 'Status'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Quantidades de eixos', 'Combustível sobre o frete', 'Status', 'Ações'],
            ['LS', '6 eixos', '30%', 'Inativo', 'Opções Visualizar Alterar Excluir'],
          ],
        )
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(
          ['Total de grupos 3', 'Grupos ativos 2', 'Grupos inativos 1'],
        )
      end

      context 'when the group has fuel in the current month' do
        before do
          create(:atua_transport_document, tenant:, axles: 9, freight_cents: 1_000_000,
                                           issued_at: Time.zone.local(2026, 10, 5, 8))
          create(:atua_transport_document, tenant:, axles: 9, freight_cents: 200_000,
                                           issued_at: Time.zone.local(2026, 9, 30, 8))
          FreightExpenses::CalculateFuelCommand.call(tenant)
        end

        scenario 'shows the group with the fuel of the month' do
          travel_to(Date.new(2026, 10, 22)) do
            visit truck_groups_path
            click_on 'Rodotrem'

            expect(page).to have_current_path(truck_group_path(rodotrem))
            expect(page).to have_css('h1.page-title', text: 'Rodotrem')
            expect(FreightExpense.fuel.count).to eq(2)
            expect(dl_to_hash('#truck_group_data')).to eq(
              'Nome' => rodotrem.name,
              'Quantidades de eixos' => '9 eixos',
              'Combustível sobre o frete' => '32,5%',
              'Status' => 'Ativo',
              'CT-es com combustível no mês' => '1',
              'Combustível do mês' => 'R$ 3.250,00',
            )
          end
        end

        scenario 'does not remove a group with fuel' do
          expect { page.driver.submit :delete, truck_group_path(rodotrem), {} }.not_to change(TruckGroup, :count)

          expect(page).to have_current_path(truck_groups_path)
          expect(page).to have_text('Não é possível excluir um grupo que já gerou despesas de combustível.')
        end
      end

      scenario 'does not show a group of another tenant' do
        visit truck_group_path(stranger_group)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when creating a group' do
      let!(:document) { create(:atua_transport_document, tenant:, number: '78001', axles: 9, freight_cents: 1_000_000) }

      scenario 'creates the group and calculates the fuel of its transport documents' do
        visit truck_groups_path
        click_on 'Novo Grupo'
        fill_in 'Nome', with: 'Rodotrem'
        check '9 eixos'

        expect(page).to have_field('Combustível sobre o frete (%)', type: 'number')

        fill_in 'Combustível sobre o frete (%)', with: '32.5'

        expect { click_on 'Cadastrar Grupo' }.to change(TruckGroup, :count).by(1).and change(FreightExpense, :count).by(1)

        truck_group = TruckGroup.last
        expect(page).to have_current_path(truck_group_path(truck_group))
        expect(page).to have_text('Grupo cadastrado com sucesso.')
        expect(truck_group).to have_attributes(tenant:, name: 'Rodotrem', axles: [9], fuel_percentage: BigDecimal('32.5'), activated?: true)
        expect(FreightExpense.last).to have_attributes(transport_document: document, kind_type: 'fuel', truck_group:, amount_cents: 325_000)
      end

      scenario 'shows the errors of the required fields' do
        visit new_truck_group_path

        expect { click_on 'Cadastrar Grupo' }.not_to change(TruckGroup, :count)

        expect(page).to have_text('Nome não pode ficar em branco')
        expect(page).to have_text('Quantidades de eixos não pode ficar em branco')
        expect(page).to have_text('Combustível sobre o frete (%) não pode ficar em branco')
      end

      scenario 'rejects a fuel percentage written as text' do
        expect do
          page.driver.submit :post, truck_groups_path, { truck_group: { name: 'Rodotrem', axles: ['9'], fuel_percentage: 'trinta' } }
        end.not_to change(TruckGroup, :count)

        expect(page.status_code).to eq(422)
        expect(page).to have_text('Combustível sobre o frete (%) não é um número')
      end

      context 'when the axle count is already in another active group' do
        before { create(:truck_group, tenant:, name: 'Rodotrem', axles: [9]) }

        scenario 'shows the validation message' do
          visit new_truck_group_path
          fill_in 'Nome', with: 'Bitrem'
          check '9 eixos'
          fill_in 'Combustível sobre o frete (%)', with: '30'

          expect { click_on 'Cadastrar Grupo' }.not_to change(TruckGroup, :count)

          expect(page).to have_text('Quantidades de eixos 9 já estão em outro grupo ativo')
        end
      end
    end

    context 'when editing a group' do
      let!(:truck_group) { create(:truck_group, tenant:, name: 'Rodotrem', axles: [9], fuel_percentage: BigDecimal('35')) }
      let!(:document) { create(:atua_transport_document, tenant:, axles: 9, freight_cents: 1_000_000) }

      before { FreightExpenses::CalculateFuelCommand.call(tenant) }

      scenario 'updates the fuel percentage and recalculates the fuel' do
        visit truck_groups_path
        within("#truck_group_#{truck_group.id} .inline-actions") { click_on 'Alterar' }

        expect(page).to have_current_path(edit_truck_group_path(truck_group))
        expect(page).to have_checked_field('9 eixos')
        expect(page).to have_field('Combustível sobre o frete (%)', with: '35')

        fill_in 'Combustível sobre o frete (%)', with: '40'

        expect { click_on 'Salvar Alterações' }.not_to change(TruckGroup, :count)

        expect(page).to have_current_path(truck_group_path(truck_group))
        expect(page).to have_text('Grupo atualizado com sucesso.')
        expect(truck_group.reload.fuel_percentage).to eq(BigDecimal('40'))
        expect(FreightExpense.fuel.sole).to have_attributes(transport_document: document, percentage: BigDecimal('40'), amount_cents: 400_000)
      end

      scenario 'deactivates the group and removes its fuel' do
        visit edit_truck_group_path(truck_group)
        uncheck 'Ativo'

        expect { click_on 'Salvar Alterações' }.not_to change(TruckGroup, :count)

        expect(page).to have_text('Grupo atualizado com sucesso.')
        expect(truck_group.reload.activated?).to be(false)
        expect(FreightExpense.count).to eq(0)
      end
    end

    context 'when removing a group without fuel' do
      let!(:truck_group) { create(:truck_group, tenant:, fuel_percentage: 0) }

      scenario 'asks for confirmation and removes the group' do
        visit truck_groups_path

        expect(page).to have_css("#truck_group_#{truck_group.id} a[data-turbo-confirm='Tem certeza que deseja excluir este grupo?']")

        expect { page.driver.submit :delete, truck_group_path(truck_group), {} }.to change(TruckGroup, :count).by(-1)

        expect(page).to have_current_path(truck_groups_path)
        expect(page).to have_text('Grupo excluído com sucesso.')
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:truck_group) { create(:truck_group, tenant:) }

    before { login_as(operator, scope: :user) }

    context 'without access to the groups' do
      scenario 'is sent back with an access denied message' do
        visit truck_groups_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the groups' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'lists the groups without the management actions' do
        visit truck_groups_path

        expect(TruckGroup.count).to eq(1)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Quantidades de eixos', 'Combustível sobre o frete', 'Status', 'Ações'],
            ['Rodotrem', '9 eixos', '35%', 'Ativo', ''],
          ],
        )
        expect(page).to have_no_link('Novo Grupo')

        click_on 'Rodotrem'

        expect(page).to have_no_link('Alterar')
      end

      scenario 'cannot change a group through a forged request' do
        page.driver.submit :patch, truck_group_path(truck_group), { truck_group: { name: 'OUTRO' } }

        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
        expect(truck_group.reload.name).to eq('Rodotrem')
      end
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:truck_group) { create(:truck_group, tenant:) }

    before { login_as(admin, scope: :user) }

    scenario 'keeps the essential columns and collapses the actions into a menu' do
      visit truck_groups_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'NOME')
      expect(page).to have_no_css('th', text: 'QUANTIDADES DE EIXOS')

      within("#truck_group_#{truck_group.id}") do
        expect(page).to have_no_css('.inline-actions')
        click_button 'Opções'
        click_on 'Alterar'
      end

      expect(page).to have_current_path(edit_truck_group_path(truck_group))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
