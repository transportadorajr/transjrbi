require 'rails_helper'

describe 'Customer country' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Clientes', slug: 'customers', writable: false) }
  let!(:customer) do
    create(:atua_customer, tenant:, code: 9101, name: 'FERROSIDER S/A', street: 'RUTA PANAMERICANA KM 51.5', city: 'EXTERIOR', state: 'EX')
  end

  context 'without a signed in user' do
    scenario 'redirects to the login screen' do
      visit edit_customer_country_path(customer)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'changes the country of the customer' do
      visit customer_path(customer)

      expect(dl_to_hash('#contact_data')).to include('País' => '- Identificado pela cidade e pelo endereço')

      click_on 'Alterar País'

      expect(page).to have_current_path(edit_customer_country_path(customer))
      expect(page).to have_css('h1.page-title', text: 'Alterar país de FERROSIDER S/A')
      expect(page).to have_text('País identificado automaticamente: -.')

      select 'Argentina', from: 'País'
      expect { click_on 'Salvar País' }.not_to change(Atua::Customer, :count)

      expect(page).to have_current_path(customer_path(customer))
      expect(page).to have_text('País do cliente atualizado.')
      expect(dl_to_hash('#contact_data')).to include('País' => 'Argentina Alterado manualmente')
      expect(customer.reload.country_type).to eq('argentina')
      expect(customer.country_edited_at).to be_present
    end

    scenario 'changes the country on a phone', :js do
      use_mobile_screen
      visit customer_path(customer)
      click_on 'Alterar País'

      select 'Paraguai', from: 'País'
      click_on 'Salvar País'

      expect(page).to have_text('País do cliente atualizado.')
      expect(customer.reload.country_type).to eq('paraguay')
    end

    context 'when the country was changed by hand' do
      let!(:customer) do
        create(:atua_customer, tenant:, name: 'ACEROS ASUNCION SA', city: 'ASUNCION', state: 'EX', country_type: 'other',
                               country_edited_at: Time.current)
      end

      scenario 'goes back to the country identified by the city' do
        visit edit_customer_country_path(customer)

        expect(page).to have_select('País', selected: 'Outro país')

        select 'Identificar automaticamente', from: 'País'
        click_on 'Salvar País'

        expect(page).to have_text('País do cliente atualizado.')
        expect(dl_to_hash('#contact_data')).to include('País' => 'Paraguai Identificado pela cidade e pelo endereço')
        expect(customer.reload).to have_attributes(country_type: 'paraguay', country_edited_at: nil)
      end
    end

    scenario 'shows the error of an unknown country' do
      page.driver.submit :patch, customer_country_path(customer), { customer_country: { country_type: 'brazil' } }

      expect(page.status_code).to eq(422)
      expect(page).to have_text('País não está incluído na lista')
      expect(customer.reload).to have_attributes(country_type: nil, country_edited_at: nil)
    end

    scenario 'cannot change the country of a customer of another tenant' do
      stranger = create(:atua_customer, tenant: other_tenant, city: 'EXTERIOR', state: 'EX')

      page.driver.submit :patch, customer_country_path(stranger), { customer_country: { country_type: 'argentina' } }

      expect(page.status_code).to eq(404)
      expect(stranger.reload.country_type).to be_nil
    end
  end

  context 'when an operator with read access is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:access) { create(:access, user: operator, resource:, reads: true) }

    before { login_as(operator, scope: :user) }

    scenario 'does not offer the country change' do
      visit customer_path(customer)

      expect(page).to have_css('h1.page-title', text: 'FERROSIDER S/A')
      expect(page).to have_no_link('Alterar País')
    end

    scenario 'cannot change the country through a forged request' do
      page.driver.submit :patch, customer_country_path(customer), { customer_country: { country_type: 'argentina' } }

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      expect(customer.reload).to have_attributes(country_type: nil, country_edited_at: nil)
    end
  end
end
