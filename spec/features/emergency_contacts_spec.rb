require 'rails_helper'

describe 'Emergency contacts', :hr do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:hr_resource) { create(:resource, name: 'Módulo de RH', slug: 'hr', writable: false) }
  let!(:resource) { create(:resource, name: 'Contatos de emergência', slug: 'emergency_contacts') }
  let!(:employees_resource) { create(:resource, name: 'Funcionários', slug: 'employees') }
  let!(:jose) { create(:employee, tenant:, name: 'JOSE SILVA', nickname: 'ZEZINHO', legal_id: '52998224725') }
  let!(:ana) { create(:employee, tenant:, name: 'ANA PAULA', legal_id: '11144477735', company_type: 'mme') }

  context 'without a signed in user', flipper: :hr do
    scenario 'redirects the quick lookup to the login screen' do
      visit emergency_contacts_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are emergency contacts' do
      let!(:maria) { create(:emergency_contact, employee: jose, name: 'Maria Silva', relationship_type: 'spouse', phone: '45999848077', position: 1) }
      let!(:pedro) do
        create(:emergency_contact, employee: jose, name: 'Pedro Silva', relationship_type: 'sibling', phone: '+5493772573358',
                                   secondary_phone: '4532541000', position: 2, notes: 'Mora na Argentina')
      end

      before do
        create(:employee, tenant:, name: 'CARLOS INATIVO', legal_id: nil, activated_at: nil)
        create(:emergency_contact, employee: create(:employee, tenant: other_tenant, name: 'FUNCIONÁRIO DE OUTRA'), name: 'Contato de Outra')
      end

      scenario 'looks up the contacts of the active employees from the HR menu' do
        visit emergency_contacts_path
        within('.sidebar-desktop') { click_on 'Contatos de emergência' }

        expect(page).to have_current_path(emergency_contacts_path)
        expect(EmergencyContact.count).to eq(3)
        expect(Employee.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            %w[Nome Empresa Contatos],
            ['ANA PAULA', 'MME', 'Sem contato'],
            ['JOSE SILVA', 'TransJR', 'Maria Silva (Cônjuge) (45) 99984-8077 Pedro Silva (Irmão(ã)) +54 93772573358 (45) 3254-1000'],
          ],
        )
        expect(page).to have_link('(45) 99984-8077', href: 'tel:+5545999848077')
        expect(page).to have_link('+54 93772573358', href: 'tel:+5493772573358')
        expect(page).to have_link('JOSE SILVA', href: employee_path(jose, anchor: 'emergency_contacts'))
        expect(page).to have_no_text('CARLOS INATIVO')
        expect(page).to have_no_text('Contato de Outra')
      end

      scenario 'searches the employee by the nickname and filters the employees without contact' do
        visit emergency_contacts_path
        within('#emergency_contacts_search') do
          fill_in 'name', with: 'zezinho'
          click_on 'Buscar'
        end

        expect(html_table_to_rows.drop(1).map(&:first)).to eq(['JOSE SILVA'])

        visit emergency_contacts_path(contact: 'missing')

        expect(html_table_to_rows.drop(1).map(&:first)).to eq(['ANA PAULA'])
      end

      scenario 'shows the emergency contacts on the employee page' do
        visit employee_path(jose)

        within('#emergency_contacts') do
          expect(html_table_to_rows).to eq(
            [
              ['Nome do contato', 'Parentesco', 'Telefone', 'Observações', 'Ações'],
              ['Maria Silva', 'Cônjuge', '(45) 99984-8077', '-', 'Opções Alterar Excluir'],
              ['Pedro Silva', 'Irmão(ã)', '+54 93772573358 (45) 3254-1000', 'Mora na Argentina', 'Opções Alterar Excluir'],
            ],
          )
          expect(page).to have_link('Cadastrar contato', href: new_employee_emergency_contact_path(jose))
        end
      end

      scenario 'edits an emergency contact' do
        visit employee_path(jose)
        within("#emergency_contact_#{maria.id}") { click_on 'Alterar', match: :first }

        expect(page).to have_field('Telefone', with: '(45) 99984-8077')
        fill_in 'Nome do contato', with: 'Maria Souza Silva'
        select 'Companheiro(a)', from: 'Parentesco'
        fill_in 'Telefone', with: '(45) 3254-2000'

        expect { click_on 'Salvar Alterações' }.not_to change(EmergencyContact, :count)

        expect(page).to have_current_path(employee_path(jose))
        expect(page).to have_text('Contato de emergência atualizado com sucesso.')
        expect(maria.reload).to have_attributes(employee: jose, name: 'Maria Souza Silva', relationship_type: 'partner', phone: '4532542000', position: 1)
      end

      scenario 'deletes an emergency contact' do
        visit employee_path(jose)

        expect { page.driver.submit :delete, emergency_contact_path(pedro), {} }.to change(EmergencyContact, :count).by(-1)

        expect(page).to have_text('Contato de emergência excluído com sucesso.')
        expect(EmergencyContact.exists?(pedro.id)).to be(false)
      end
    end

    scenario 'registers an emergency contact from the employee page' do
      visit employee_path(ana)
      within('#emergency_contacts') { click_on 'Cadastrar contato' }

      expect(page).to have_field('Prioridade', with: '1')
      fill_in 'Nome do contato', with: 'João Paula'
      select 'Pai', from: 'Parentesco'
      fill_in 'Telefone', with: '(45) 99916-4060'
      fill_in 'Observações', with: 'Ligar depois das 18h'

      expect { click_on 'Cadastrar Contato' }.to change(EmergencyContact, :count).by(1)

      expect(page).to have_current_path(employee_path(ana))
      expect(page).to have_text('Contato de emergência cadastrado com sucesso.')
      expect(EmergencyContact.last).to have_attributes(tenant:, employee: ana, name: 'João Paula', relationship_type: 'father', phone: '45999164060',
                                                       secondary_phone: nil, position: 1, notes: 'Ligar depois das 18h')
    end

    scenario 'shows the validation errors of the emergency contact' do
      visit new_employee_emergency_contact_path(ana)

      fill_in 'Telefone', with: '9916-4060'

      expect { click_on 'Cadastrar Contato' }.not_to change(EmergencyContact, :count)

      expect(page).to have_text('Nome do contato não pode ficar em branco e Telefone deve ter o DDD e o número, ou o código do país antes')
    end

    context 'when another tenant has an emergency contact' do
      let!(:stranger) { create(:emergency_contact, employee: create(:employee, tenant: other_tenant, name: 'FUNCIONÁRIO DE OUTRA')) }

      scenario 'does not reach the emergency contact of another tenant' do
        visit edit_emergency_contact_path(stranger)

        expect(page.status_code).to eq(404)
      end
    end
  end

  context 'when a user reads the employees without access to the emergency contacts', flipper: :hr do
    let!(:operator) { create(:user, tenant:) }

    before do
      create(:emergency_contact, employee: jose, name: 'Maria Silva')
      create(:access, user: operator, resource: hr_resource, creates: false)
      create(:access, user: operator, resource: employees_resource, creates: true)
      login_as(operator, scope: :user)
    end

    scenario 'does not see the personal data of the emergency contacts' do
      visit employee_path(jose)

      expect(page).to have_css('h1.page-title', text: 'JOSE SILVA')
      expect(page).to have_no_css('#emergency_contacts')
      expect(page).to have_no_text('Maria Silva')
      expect(page).to have_no_link('Contatos de emergência')

      visit emergency_contacts_path

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      expect(page).to have_no_text('Maria Silva')

      expect do
        page.driver.submit :post, employee_emergency_contacts_path(jose), { emergency_contact: { name: 'Outro', phone: '45999848077' } }
      end.not_to change(EmergencyContact, :count)
    end
  end

  context 'when a user reads the emergency contacts without changing them', flipper: :hr do
    let!(:operator) { create(:user, tenant:) }

    before do
      create(:emergency_contact, employee: jose, name: 'Maria Silva')
      create(:access, user: operator, resource: hr_resource, creates: false)
      create(:access, user: operator, resource:, creates: false)
      login_as(operator, scope: :user)
    end

    scenario 'looks up the contacts without the employee link and the actions' do
      visit emergency_contacts_path

      expect(Employee.count).to eq(2)
      expect(EmergencyContact.count).to eq(1)
      expect(html_table_to_rows).to eq(
        [
          %w[Nome Empresa Contatos],
          ['ANA PAULA', 'MME', 'Sem contato'],
          ['JOSE SILVA', 'TransJR', 'Maria Silva (Cônjuge) (45) 99984-8077'],
        ],
      )
      expect(page).to have_no_link('JOSE SILVA')
    end
  end

  context 'when the owner is signed in on a phone', :js, flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before do
      create(:emergency_contact, employee: jose, name: 'Maria Silva', relationship_type: 'spouse', phone: '45999848077')
      use_mobile_screen
      login_as(owner, scope: :user)
    end

    scenario 'searches the employee and shows the phone to dial' do
      visit emergency_contacts_path
      within('#emergency_contacts_search') do
        fill_in 'name', with: 'jose'
        click_on 'Buscar'
      end

      expect(page).to have_no_css('td', text: 'ANA PAULA')
      expect(page).to have_link('(45) 99984-8077', href: 'tel:+5545999848077')
      expect(page).to have_no_css('th', text: 'Empresa')
    end

    scenario 'types the phone with the mask' do
      visit new_employee_emergency_contact_path(ana)

      fill_in 'Nome do contato', with: 'Paula'
      fill_in 'Telefone', with: '45999164060'

      expect(page).to have_field('Telefone', with: '(45) 99916-4060')

      expect { click_on 'Cadastrar Contato' }.to change(EmergencyContact, :count).by(1)

      expect(page).to have_text('Contato de emergência cadastrado com sucesso.')
      expect(EmergencyContact.last).to have_attributes(employee: ana, name: 'Paula', phone: '45999164060')
    end
  end
end
