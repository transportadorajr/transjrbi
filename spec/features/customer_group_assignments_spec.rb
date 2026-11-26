require 'rails_helper'

describe 'Customer group assignment' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Clientes', slug: 'customers', writable: false) }
  let!(:gerdau) { create(:customer_group, tenant:, name: 'GERDAU', terms: ['GERDAU']) }
  let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
  let!(:inactive_group) { create(:customer_group, tenant:, name: 'MOVISTAR', activated_at: nil) }
  let!(:customer) { create(:atua_customer, tenant:, name: 'ACOMINAS S.A.', trade_name: 'GERDAU OURO BRANCO') }

  context 'without a signed in user' do
    scenario 'redirects to the login screen' do
      visit edit_customer_customer_group_path(customer)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when the customer is a taker without a group' do
      let!(:document) { create(:atua_transport_document, tenant:, taker_code: customer.code) }

      scenario 'puts the taker into a group' do
        visit customers_path(customer_group: 'none')

        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Grupo', 'CPF/CNPJ', 'Cidade', 'Atividade', 'Ações'],
            ['ACOMINAS S.A. GERDAU OURO BRANCO', '-', '17.469.701/0066-12', 'JOAO MONLEVADE/MG', '-', ''],
          ],
        )

        click_on 'ACOMINAS S.A.'
        click_on 'Alterar Grupo'

        expect(page).to have_current_path(edit_customer_customer_group_path(customer))
        expect(page).to have_css('h1.page-title', text: 'Alterar grupo de ACOMINAS S.A.')
        expect(page).to have_select('Grupo', options: ['Selecione o grupo', 'GERDAU', 'USIMINAS'])

        select 'GERDAU', from: 'Grupo'
        expect { click_on 'Salvar Grupo' }.to have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id)
          .and not_change(Atua::Customer, :count)

        expect(page).to have_current_path(customer_path(customer))
        expect(page).to have_text('Grupo do cliente atualizado.')
        expect(dl_to_hash('#customer_data')).to include('Grupo' => 'GERDAU')
        expect(customer.reload.customer_group).to eq(gerdau)
        expect(customer.customer_group_edited_at).to be_present
        expect(Atua::Customer.count).to eq(1)
      end
    end

    context 'when the customer is already in a group' do
      let!(:customer) { create(:atua_customer, tenant:, name: 'ACOMINAS S.A.', customer_group: usiminas) }

      scenario 'moves the customer to another group' do
        visit edit_customer_customer_group_path(customer)

        expect(page).to have_select('Grupo', selected: 'USIMINAS')

        select 'GERDAU', from: 'Grupo'
        expect { click_on 'Salvar Grupo' }.not_to change(Atua::Customer, :count)

        expect(page).to have_text('Grupo do cliente atualizado.')
        expect(customer.reload.customer_group).to eq(gerdau)
        expect(customer.customer_group_edited_at).to be_present
      end
    end

    scenario 'changes the group on a phone', :js do
      use_mobile_screen
      visit customer_path(customer)
      click_on 'Alterar Grupo'

      select 'USIMINAS', from: 'Grupo'
      expect { click_on 'Salvar Grupo' }.not_to change(Atua::Customer, :count)

      expect(page).to have_text('Grupo do cliente atualizado.')
      expect(customer.reload.customer_group).to eq(usiminas)
      expect(customer.customer_group_edited_at).to be_present
    end

    scenario 'shows the error when no group is chosen' do
      visit edit_customer_customer_group_path(customer)
      click_on 'Salvar Grupo'

      expect(page).to have_text('Grupo não pode ficar em branco')
      expect(customer.reload.customer_group).to be_nil
    end

    scenario 'cannot put a customer into an inactive group' do
      page.driver.submit :patch, customer_customer_group_path(customer), { customer_group_assignment: { customer_group_id: inactive_group.id } }

      expect(page.status_code).to eq(422)
      expect(page).to have_text('Grupo não é válido')
      expect(customer.reload.customer_group).to be_nil
    end

    context 'when the customer belongs to another tenant' do
      let!(:stranger) { create(:atua_customer, tenant: other_tenant, name: 'CLIENTE DE OUTRA EMPRESA') }

      scenario 'cannot change the group of the customer' do
        page.driver.submit :patch, customer_customer_group_path(stranger), { customer_group_assignment: { customer_group_id: gerdau.id } }

        expect(page.status_code).to eq(404)
        expect(stranger.reload.customer_group).to be_nil
      end
    end
  end

  context 'when an operator with read access is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:access) { create(:access, user: operator, resource:, reads: true) }

    before { login_as(operator, scope: :user) }

    scenario 'does not offer the group change' do
      visit customer_path(customer)

      expect(page).to have_css('h1.page-title', text: 'ACOMINAS S.A.')
      expect(page).to have_no_link('Alterar Grupo')
    end

    scenario 'cannot change the group through a forged request' do
      page.driver.submit :patch, customer_customer_group_path(customer), { customer_group_assignment: { customer_group_id: gerdau.id } }

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      expect(customer.reload.customer_group).to be_nil
    end
  end
end
