require 'rails_helper'

describe 'Suppliers', :maintenance do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Fornecedores', slug: 'suppliers') }
  let!(:maintenance_resource) { create(:resource, name: 'Módulo de manutenção', slug: 'maintenance', writable: false) }

  context 'without a signed in user' do
    scenario 'redirects the listing to the login screen' do
      visit suppliers_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the maintenance flag is off' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'does not open the listing' do
      visit suppliers_path

      expect(page.status_code).to eq(404)
    end
  end

  context 'when the owner is signed in', flipper: :maintenance do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are no suppliers' do
      scenario 'shows the empty state message' do
        visit suppliers_path

        expect(Supplier.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are suppliers' do
      let!(:grinding) { create(:supplier, tenant:, name: 'RETÍFICA IPATINGA', document: '12.345.678/0001-90') }
      let!(:tires) { create(:supplier, tenant:, name: 'BORRACHARIA CENTRAL', active: false) }
      let!(:stranger) { create(:supplier, tenant: other_tenant, name: 'FORNECEDOR DE OUTRA') }

      scenario 'lists the suppliers from the maintenance menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Fornecedores'
        end

        expect(page).to have_current_path(suppliers_path)
        expect(Supplier.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'CNPJ / CPF', 'Ativo', 'Ações'],
            ['BORRACHARIA CENTRAL', '-', 'Inativo', 'Opções Alterar Ativar'],
            ['RETÍFICA IPATINGA', '12.345.678/0001-90', 'Ativo', 'Opções Alterar Inativar'],
          ],
        )
        expect(page).to have_link('Novo Fornecedor', href: new_supplier_path)
        expect(page).to have_no_text('FORNECEDOR DE OUTRA')
      end

      scenario 'filters the suppliers by name' do
        visit suppliers_path
        fill_in 'Nome', with: 'ipatinga'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows.drop(1).map(&:first)).to eq(['RETÍFICA IPATINGA'])
      end

      scenario 'edits a supplier' do
        visit suppliers_path
        within("#supplier_#{tires.id} .inline-actions") { click_on 'Alterar' }

        fill_in 'CNPJ / CPF', with: '123.456.789-09'
        check 'Ativo'

        expect { click_on 'Salvar Alterações' }.not_to change(Supplier, :count)

        expect(page).to have_current_path(suppliers_path)
        expect(page).to have_text('Fornecedor atualizado com sucesso.')
        expect(tires.reload).to have_attributes(name: 'BORRACHARIA CENTRAL', document: '123.456.789-09', active: true)
      end

      scenario 'does not edit a supplier of another tenant' do
        visit edit_supplier_path(stranger)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when changing the status of a supplier' do
      let!(:active_supplier) { create(:supplier, tenant:, name: 'RETÍFICA IPATINGA') }
      let!(:inactive_supplier) { create(:supplier, tenant:, name: 'BORRACHARIA CENTRAL', active: false) }
      let!(:stranger_supplier) { create(:supplier, tenant: other_tenant, name: 'FORNECEDOR DE OUTRA') }

      scenario 'offers the toggle that matches the status of each supplier' do
        visit suppliers_path

        expect(Supplier.count).to eq(3)
        expect(page).to have_link('Inativar', href: deactivate_supplier_path(active_supplier))
        expect(page).to have_link('Ativar', href: activate_supplier_path(inactive_supplier))
      end

      scenario 'deactivates an active supplier from the listing' do
        visit suppliers_path

        expect { page.driver.submit :patch, deactivate_supplier_path(active_supplier), {} }.not_to change(Supplier, :count)

        expect(page).to have_current_path(suppliers_path)
        expect(page).to have_text('Registro inativado com sucesso.')
        expect(active_supplier.reload).not_to be_active
      end

      scenario 'activates an inactive supplier from the listing' do
        visit suppliers_path

        expect { page.driver.submit :patch, activate_supplier_path(inactive_supplier), {} }.not_to change(Supplier, :count)

        expect(page).to have_current_path(suppliers_path)
        expect(page).to have_text('Registro ativado com sucesso.')
        expect(inactive_supplier.reload).to be_active
      end

      scenario 'does not change the status of a supplier of another tenant' do
        page.driver.submit :patch, deactivate_supplier_path(stranger_supplier), {}

        expect(page.status_code).to eq(404)
        expect(stranger_supplier.reload).to be_active
      end
    end

    context 'when creating a supplier' do
      let!(:grinding) { create(:supplier, tenant:, name: 'RETÍFICA IPATINGA') }

      scenario 'creates a supplier' do
        visit suppliers_path
        click_on 'Novo Fornecedor'

        fill_in 'Nome', with: 'Auto Elétrica Vale'
        fill_in 'CNPJ / CPF', with: '98.765.432/0001-10'

        expect { click_on 'Cadastrar Fornecedor' }.to change(Supplier, :count).by(1)

        expect(page).to have_current_path(suppliers_path)
        expect(page).to have_text('Fornecedor cadastrado com sucesso.')
        expect(Supplier.last).to have_attributes(tenant:, name: 'AUTO ELÉTRICA VALE', document: '98.765.432/0001-10', active: true)
      end

      scenario 'shows the error of a name already registered' do
        visit new_supplier_path

        fill_in 'Nome', with: 'retífica ipatinga'

        expect { click_on 'Cadastrar Fornecedor' }.not_to change(Supplier, :count)

        expect(page).to have_text('Nome já está cadastrado')
      end
    end
  end

  context 'when a user without access to the suppliers is signed in', flipper: :maintenance do
    let!(:operator) { create(:user, tenant:) }
    let!(:maintenance_access) { create(:access, user: operator, resource: maintenance_resource, creates: false) }

    before { login_as(operator, scope: :user) }

    scenario 'cannot open the listing nor create a supplier' do
      visit suppliers_path

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')

      expect { page.driver.submit :post, suppliers_path, { supplier: { name: 'OFICINA' } } }.not_to change(Supplier, :count)
    end
  end
end
