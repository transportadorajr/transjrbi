require 'rails_helper'

describe 'Customers' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Clientes', slug: 'customers', writable: false) }

  context 'without a signed in user' do
    let!(:customer) { create(:atua_customer, tenant:) }

    scenario 'redirects the listing to the login screen' do
      visit customers_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'redirects the details to the login screen' do
      visit customer_path(customer)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when there are no customers' do
      scenario 'shows the empty state message' do
        visit customers_path

        expect(Atua::Customer.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are customers' do
      let!(:steel_group) { create(:customer_group, tenant:, name: 'ARCELORMITTAL', terms: ['ARCELOR']) }
      let!(:steel) do
        create(:atua_customer, tenant:, customer_group: steel_group, name: 'ARCELORMITTAL BRASIL S.A.', trade_name: 'ARCELOR MONLEVADE', document: '17.469.701/0066-12',
                               document_digits: '17469701006612', city: 'JOAO MONLEVADE', state: 'MG', activity: 'INDUSTRIA METALURGICA')
      end
      let!(:warehouse) do
        create(:atua_customer, tenant:, name: 'TL ARMAZENS GERAIS LTDA.', trade_name: nil, document: '10.622.725/0001-75',
                               document_digits: '10622725000175', city: 'IPATINGA', state: 'MG', activity: nil)
      end
      let!(:removed) { create(:atua_customer, tenant:, name: 'METAL WIRE LTDA', removed_from_atua_at: Time.current) }
      let!(:stranger) { create(:atua_customer, tenant: other_tenant, name: 'CLIENTE DE OUTRA EMPRESA') }

      scenario 'lists the active customers of the tenant from the registrations menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Clientes'
        end

        expect(page).to have_current_path(customers_path)
        expect(Atua::Customer.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Grupo', 'CPF/CNPJ', 'Cidade', 'Atividade', 'Ações'],
            ['ARCELORMITTAL BRASIL S.A. ARCELOR MONLEVADE', 'ARCELORMITTAL', '17.469.701/0066-12', 'JOAO MONLEVADE/MG', 'INDUSTRIA METALURGICA', ''],
            ['TL ARMAZENS GERAIS LTDA. -', '-', '10.622.725/0001-75', 'IPATINGA/MG', '-', ''],
          ],
        )
        expect(page).to have_text('2 registros')
        expect(page).to have_link(href: customer_path(steel), title: 'Visualizar')
        expect(page).to have_no_text('METAL WIRE LTDA')
        expect(page).to have_no_text('CLIENTE DE OUTRA EMPRESA')
      end

      scenario 'filters the customers by name' do
        visit customers_path
        fill_in 'Nome ou nome fantasia', with: 'monlevade'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Grupo', 'CPF/CNPJ', 'Cidade', 'Atividade', 'Ações'],
            ['ARCELORMITTAL BRASIL S.A. ARCELOR MONLEVADE', 'ARCELORMITTAL', '17.469.701/0066-12', 'JOAO MONLEVADE/MG', 'INDUSTRIA METALURGICA', ''],
          ],
        )
      end

      scenario 'filters the customers by document and city' do
        visit customers_path
        fill_in 'CPF/CNPJ', with: '10.622.725/0001-75'
        fill_in 'Cidade', with: 'ipatinga'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Grupo', 'CPF/CNPJ', 'Cidade', 'Atividade', 'Ações'],
            ['TL ARMAZENS GERAIS LTDA. -', '-', '10.622.725/0001-75', 'IPATINGA/MG', '-', ''],
          ],
        )
      end

      scenario 'filters the customers by group' do
        visit customers_path
        select 'ARCELORMITTAL', from: 'Grupo'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Grupo', 'CPF/CNPJ', 'Cidade', 'Atividade', 'Ações'],
            ['ARCELORMITTAL BRASIL S.A. ARCELOR MONLEVADE', 'ARCELORMITTAL', '17.469.701/0066-12', 'JOAO MONLEVADE/MG', 'INDUSTRIA METALURGICA', ''],
          ],
        )
      end

      scenario 'does not show a customer removed from Atua' do
        visit customer_path(removed)

        expect(page.status_code).to eq(404)
      end

      scenario 'does not show a customer of another tenant' do
        visit customer_path(stranger)

        expect(page.status_code).to eq(404)
      end

      scenario 'has no route to create a customer' do
        expect { page.driver.submit :post, customers_path, {} }.not_to change(Atua::Customer, :count)

        expect(page.status_code).to eq(404)
      end

      scenario 'has no route to remove a customer' do
        expect { page.driver.submit :delete, customer_path(steel), {} }.not_to change(Atua::Customer, :count)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when a customer has every detail' do
      let!(:customer_group) { create(:customer_group, tenant:, name: 'ARCELORMITTAL', terms: ['ARCELOR']) }
      let!(:customer) do
        create(:atua_customer, tenant:, customer_group:, code: 7752, name: 'ARCELORMITTAL BRASIL S.A.', trade_name: 'ARCELOR MONLEVADE',
                               person_kind: 'Pessoa Jurídica', document: '17.469.701/0066-12', state_registration: '3620031410092',
                               activity: 'INDUSTRIA METALURGICA', status: 'Normal', registered_on: Date.new(2019, 3, 12),
                               last_billed_on: Date.new(2026, 10, 1), street: 'AV. GETULIO VARGAS, 100', complement: 'PORTARIA 2',
                               district: 'CENTRO', zip_code: '35930000', city: 'JOAO MONLEVADE', state: 'MG', phone: '(31) 3859-1000',
                               emails: %w[logistica@arcelor.com fiscal@arcelor.com], payment_method: 'Boleto', payment_term: '30 dias')
      end

      scenario 'shows every detail of the customer' do
        visit customers_path
        click_on 'ARCELORMITTAL BRASIL S.A.'

        expect(page).to have_current_path(customer_path(customer))
        expect(page).to have_css('h1.page-title', text: 'ARCELORMITTAL BRASIL S.A.')
        expect(dl_to_hash('#customer_data')).to eq(
          'Código' => '7752',
          'Nome' => 'ARCELORMITTAL BRASIL S.A.',
          'Nome fantasia' => 'ARCELOR MONLEVADE',
          'Grupo' => 'ARCELORMITTAL',
          'Tipo de pessoa' => 'Pessoa Jurídica',
          'CPF/CNPJ' => '17.469.701/0066-12',
          'Inscrição estadual' => '3620031410092',
          'Atividade' => 'INDUSTRIA METALURGICA',
          'Situação na Atua' => 'Normal',
          'Cadastrado em' => '12/03/2019',
          'Última emissão como pagador' => '01/10/2026',
        )
        expect(dl_to_hash('#contact_data')).to eq(
          'Endereço' => 'AV. GETULIO VARGAS, 100, PORTARIA 2, CENTRO',
          'CEP' => '35930000',
          'Cidade' => 'JOAO MONLEVADE/MG',
          'Telefone' => '(31) 3859-1000',
          'E-mails' => 'logistica@arcelor.com, fiscal@arcelor.com',
          'Forma de pagamento' => 'Boleto',
          'Prazo de pagamento' => '30 dias',
        )
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:customer) { create(:atua_customer, tenant:, name: 'ARCELORMITTAL BRASIL S.A.') }

    before { login_as(operator, scope: :user) }

    context 'without access to the customers' do
      scenario 'is sent back with an access denied message' do
        visit customers_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end

      scenario 'cannot open a customer' do
        visit customer_path(customer)

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the customers' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'lists and opens the customers' do
        visit customers_path

        expect(Atua::Customer.count).to eq(1)
        expect(html_table_to_rows.size).to eq(2)

        click_on 'ARCELORMITTAL BRASIL S.A.'

        expect(page).to have_current_path(customer_path(customer))
      end
    end
  end

  context 'on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:customer) { create(:atua_customer, tenant:, name: 'ARCELORMITTAL BRASIL S.A.') }

    before do
      login_as(admin, scope: :user)
      use_mobile_screen
    end

    scenario 'keeps only the essential columns without horizontal scroll' do
      visit customers_path

      expect(page).to have_link('ARCELORMITTAL BRASIL S.A.')
      expect(page).to have_no_css('th', text: 'CPF/CNPJ')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
