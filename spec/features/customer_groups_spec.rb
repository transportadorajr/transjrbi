require 'rails_helper'

describe 'Customer groups' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Grupos de clientes', slug: 'customer_groups') }
  let!(:customers_resource) { create(:resource, name: 'Clientes', slug: 'customers', writable: false) }

  context 'without a signed in user' do
    let!(:customer_group) { create(:customer_group, tenant:) }

    scenario 'redirects the listing to the login screen' do
      visit customer_groups_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'does not create a group' do
      expect do
        page.driver.submit :post, customer_groups_path, { customer_group: { name: 'TERRAFEC' } }
      end.not_to change(CustomerGroup, :count)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when there are no groups' do
      scenario 'shows the empty state message' do
        visit customer_groups_path

        expect(CustomerGroup.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are groups' do
      let!(:food) { create(:customer_group, tenant:, name: 'TERRAFEC', terms: ['2JM', 'TERRINHA ALIMENTOS']) }
      let!(:phone) { create(:customer_group, tenant:, name: 'MOVISTAR', terms: [], activated_at: nil) }
      let!(:stranger_group) { create(:customer_group, tenant: other_tenant, name: 'GRUPO DE OUTRA EMPRESA') }
      let!(:jm) { create(:atua_customer, tenant:, name: '2JM COMERCIO LTDA', customer_group: food) }
      let!(:terrinha) { create(:atua_customer, tenant:, name: 'TERRINHA ALIMENTOS LTDA', customer_group: food) }
      let!(:removed) { create(:atua_customer, tenant:, name: 'TERRINHA ANTIGA', customer_group: food, removed_from_atua_at: Time.current) }

      scenario 'lists the groups of the tenant from the registrations menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Grupos de clientes'
        end

        expect(page).to have_current_path(customer_groups_path)
        expect(CustomerGroup.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Clientes', 'Termos', 'Status', 'Ações'],
            ['MOVISTAR', '0', 'Sem termos', 'Inativo', 'Opções Visualizar Alterar Excluir'],
            ['TERRAFEC', '2', '2JM, TERRINHA ALIMENTOS', 'Ativo', 'Opções Visualizar Alterar Excluir'],
          ],
        )
        expect(page).to have_css('.counter-card', text: "Total de grupos\n2")
        expect(page).to have_css('.counter-card', text: "Grupos ativos\n1")
        expect(page).to have_css('.counter-card', text: "Grupos inativos\n1")
        expect(page).to have_link('Novo Grupo', href: new_customer_group_path)
        expect(page).to have_no_text('GRUPO DE OUTRA EMPRESA')
      end

      scenario 'filters the groups by name and status' do
        visit customer_groups_path
        fill_in 'Nome do grupo', with: 'terra'
        select 'Ativo', from: 'Status'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Clientes', 'Termos', 'Status', 'Ações'],
            ['TERRAFEC', '2', '2JM, TERRINHA ALIMENTOS', 'Ativo', 'Opções Visualizar Alterar Excluir'],
          ],
        )
      end

      scenario 'shows the group with its active customers' do
        visit customer_groups_path
        click_on 'TERRAFEC'

        expect(page).to have_current_path(customer_group_path(food))
        expect(Atua::Customer.count).to eq(3)
        expect(page).to have_css('h1.page-title', text: 'TERRAFEC')
        expect(dl_to_hash('#customer_group_data')).to eq(
          'Nome' => 'TERRAFEC',
          'Termos' => '2JM, TERRINHA ALIMENTOS',
          'Status' => 'Ativo',
          'Clientes' => '2',
        )
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'CPF/CNPJ', 'Cidade', 'Ações'],
            ['2JM COMERCIO LTDA -', '17.469.701/0066-12', 'JOAO MONLEVADE/MG', ''],
            ['TERRINHA ALIMENTOS LTDA -', '17.469.701/0066-12', 'JOAO MONLEVADE/MG', ''],
          ],
        )
        expect(page).to have_link(href: customer_path(jm), title: 'Visualizar')
        expect(page).to have_no_text('TERRINHA ANTIGA')
      end

      scenario 'does not show a group of another tenant' do
        visit customer_group_path(stranger_group)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when creating a group' do
      scenario 'creates an active group with its terms' do
        visit customer_groups_path
        click_on 'Novo Grupo'
        fill_in 'Nome', with: 'TERRAFEC'
        fill_in 'Termos', with: "2JM\nTERRINHA ALIMENTOS"

        expect { click_on 'Cadastrar Grupo' }.to change(CustomerGroup, :count).by(1)

        customer_group = CustomerGroup.last
        expect(page).to have_current_path(customer_group_path(customer_group))
        expect(page).to have_text('Grupo cadastrado com sucesso.')
        expect(customer_group.tenant).to eq(tenant)
        expect(customer_group.name).to eq('TERRAFEC')
        expect(customer_group.terms).to eq(['2JM', 'TERRINHA ALIMENTOS'])
        expect(customer_group.activated_at).to be_present
      end

      scenario 'creates an inactive group' do
        visit new_customer_group_path
        fill_in 'Nome', with: 'MOVISTAR'
        uncheck 'Ativo'

        expect { click_on 'Cadastrar Grupo' }.to change(CustomerGroup, :count).by(1)

        customer_group = CustomerGroup.last
        expect(customer_group.name).to eq('MOVISTAR')
        expect(customer_group.terms).to eq([])
        expect(customer_group.activated_at).to be_nil
      end

      scenario 'shows the errors of the required fields' do
        visit new_customer_group_path

        expect { click_on 'Cadastrar Grupo' }.not_to change(CustomerGroup, :count)

        expect(page).to have_text('Nome não pode ficar em branco')
      end

      context 'when the name is already taken' do
        let!(:existing_group) { create(:customer_group, tenant:, name: 'TERRAFEC') }

        scenario 'shows the validation message' do
          visit new_customer_group_path
          fill_in 'Nome', with: 'TERRAFEC'

          expect { click_on 'Cadastrar Grupo' }.not_to change(CustomerGroup, :count)

          expect(page).to have_text('Nome já está em uso por outro grupo')
        end
      end
    end

    context 'when editing a group' do
      let!(:customer_group) { create(:customer_group, tenant:, name: 'TERRAFEC', terms: ['2JM']) }

      scenario 'updates the group data' do
        visit customer_groups_path
        within("#customer_group_#{customer_group.id} .inline-actions") { click_on 'Alterar' }

        expect(page).to have_current_path(edit_customer_group_path(customer_group))
        expect(page).to have_field('Termos', with: '2JM')

        fill_in 'Nome', with: 'TERRAFEC ALIMENTOS'
        fill_in 'Termos', with: "2JM\nTERRAFEC"
        uncheck 'Ativo'

        expect { click_on 'Salvar Alterações' }.not_to change(CustomerGroup, :count)

        expect(page).to have_current_path(customer_group_path(customer_group))
        expect(page).to have_text('Grupo atualizado com sucesso.')

        customer_group.reload
        expect(customer_group.name).to eq('TERRAFEC ALIMENTOS')
        expect(customer_group.terms).to eq(%w[2JM TERRAFEC])
        expect(customer_group.activated_at).to be_nil
      end

      scenario 'shows the errors when the name is removed' do
        visit edit_customer_group_path(customer_group)
        fill_in 'Nome', with: ''
        click_on 'Salvar Alterações'

        expect(page).to have_text('Nome não pode ficar em branco')
        expect(customer_group.reload.name).to eq('TERRAFEC')
      end
    end

    context 'when removing a group' do
      let!(:customer_group) { create(:customer_group, tenant:, name: 'MOVISTAR') }

      scenario 'removes the group without customers' do
        visit customer_groups_path

        expect(page).to have_css("#customer_group_#{customer_group.id} a[data-turbo-confirm='Tem certeza que deseja excluir este grupo?']")

        expect { page.driver.submit :delete, customer_group_path(customer_group), {} }.to change(CustomerGroup, :count).by(-1)

        expect(page).to have_current_path(customer_groups_path)
        expect(page).to have_text('Grupo excluído com sucesso.')
      end

      context 'when the group has customers' do
        let!(:customer) { create(:atua_customer, tenant:, customer_group:) }

        scenario 'keeps the group and explains why' do
          expect { page.driver.submit :delete, customer_group_path(customer_group), {} }.not_to change(CustomerGroup, :count)

          expect(page).to have_current_path(customer_groups_path)
          expect(page).to have_text('Não é possível excluir um grupo com clientes, regras de comissão ou custos por tonelada vinculados. Desative o grupo para deixar de usá-lo.')
        end
      end
    end

    context 'when regrouping the customers of a group' do
      let!(:food) { create(:customer_group, tenant:, name: 'TERRAFEC', terms: ['TERRINHA ALIMENTOS']) }
      let!(:own_group) { create(:customer_group, tenant:, name: 'TERRINHA ALIMENTOS LTDA') }
      let!(:customer) { create(:atua_customer, tenant:, name: 'TERRINHA ALIMENTOS LTDA', customer_group: own_group) }

      scenario 'moves the matching customers into the group' do
        visit customer_group_path(food)

        expect(page).to have_css("form[action='#{regroup_customer_group_path(food)}'] button[data-turbo-confirm]")

        expect { click_on 'Reagrupar' }.to change(CustomerGroup, :count).by(-1)

        expect(page).to have_current_path(customer_group_path(food))
        expect(page).to have_text('1 cliente foi movido para este grupo.')
        expect(customer.reload.customer_group).to eq(food)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'CPF/CNPJ', 'Cidade', 'Ações'],
            ['TERRINHA ALIMENTOS LTDA -', '17.469.701/0066-12', 'JOAO MONLEVADE/MG', ''],
          ],
        )
      end

      scenario 'recalculates the commissions after moving customers' do
        visit customer_group_path(food)

        expect { click_on 'Reagrupar' }.to have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id)
      end

      scenario 'does not offer the action on a group without terms' do
        visit customer_group_path(own_group)

        expect(page).to have_css('h1.page-title', text: 'TERRINHA ALIMENTOS LTDA')
        expect(page).to have_no_button('Reagrupar')
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:customer_group) { create(:customer_group, tenant:, name: 'TERRAFEC', terms: ['2JM']) }

    before { login_as(operator, scope: :user) }

    context 'without access to the groups' do
      scenario 'is sent back with an access denied message' do
        visit customer_groups_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the groups' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'lists the groups without the management actions' do
        visit customer_groups_path

        expect(CustomerGroup.count).to eq(1)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Clientes', 'Termos', 'Status', 'Ações'],
            ['TERRAFEC', '0', '2JM', 'Ativo', ''],
          ],
        )
        expect(page).to have_link(href: customer_group_path(customer_group), title: 'Visualizar')
        expect(page).to have_no_link('Novo Grupo')

        click_on 'TERRAFEC'

        expect(page).to have_no_link('Alterar')
        expect(page).to have_no_button('Reagrupar')
      end

      scenario 'cannot remove a group through a forged request' do
        expect { page.driver.submit :delete, customer_group_path(customer_group), {} }.not_to change(CustomerGroup, :count)

        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end

      scenario 'cannot regroup through a forged request' do
        page.driver.submit :patch, regroup_customer_group_path(customer_group), {}

        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with write access to the groups' do
      let!(:access) { create(:access, user: operator, resource:, reads: true, creates: true) }

      scenario 'creates a group' do
        visit new_customer_group_path
        fill_in 'Nome', with: 'VIRGINIA'

        expect { click_on 'Cadastrar Grupo' }.to change(CustomerGroup, :count).by(1)

        expect(CustomerGroup.last.name).to eq('VIRGINIA')
      end
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:customer_group) { create(:customer_group, tenant:, name: 'TERRAFEC', terms: ['2JM']) }

    before { login_as(admin, scope: :user) }

    scenario 'keeps the essential columns and collapses the actions into a menu' do
      visit customer_groups_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'NOME')
      expect(page).to have_no_css('th', text: 'TERMOS')

      within("#customer_group_#{customer_group.id}") do
        expect(page).to have_no_css('.inline-actions')
        click_button 'Opções'
        click_on 'Alterar'
      end

      expect(page).to have_current_path(edit_customer_group_path(customer_group))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
