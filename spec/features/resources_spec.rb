require 'rails_helper'

describe 'Resources' do
  let!(:tenant) { create(:tenant) }

  context 'without a signed in user' do
    let!(:resource) { create(:resource, name: 'Fretes', slug: 'freights') }

    scenario 'redirects to the login screen' do
      visit resources_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'does not create a resource' do
      expect do
        page.driver.submit :post, resources_path, { resource: { name: 'Viagens', slug: 'trips', writable: '1' } }
      end.not_to change(Resource, :count)

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'does not remove a resource' do
      expect { page.driver.submit :delete, resource_path(resource), {} }.not_to change(Resource, :count)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, name: 'Arthur Dono', user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are no resources' do
      scenario 'shows the empty state message' do
        visit resources_path

        expect(Resource.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are resources' do
      let!(:freight_resource) { create(:resource, name: 'Fretes', slug: 'freights', writable: true) }
      let!(:report_resource) { create(:resource, name: 'Relatórios', slug: 'reports', writable: false) }

      scenario 'lists every resource with its name, slug and writable status' do
        visit root_path
        within('.sidebar-desktop') { click_on 'Recursos' }

        expect(page).to have_current_path(resources_path)
        expect(Resource.count).to eq(2)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Identificador', 'Permite edição', 'Ações'],
            ['Fretes', 'freights', 'Leitura e edição', 'Opções Alterar Excluir'],
            ['Relatórios', 'reports', 'Somente leitura', 'Opções Alterar Excluir'],
          ],
        )
        expect(page).to have_text('2 registros')
        expect(page).to have_link('Novo Recurso', href: new_resource_path)
      end

      scenario 'filters the resources by name' do
        visit resources_path
        fill_in 'Nome do recurso', with: 'fret'
        click_on 'Aplicar Filtros'

        expect(Resource.count).to eq(2)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Identificador', 'Permite edição', 'Ações'],
            ['Fretes', 'freights', 'Leitura e edição', 'Opções Alterar Excluir'],
          ],
        )
      end

      scenario 'filters the resources by slug' do
        visit resources_path(slug: 'report')

        expect(Resource.count).to eq(2)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Identificador', 'Permite edição', 'Ações'],
            ['Relatórios', 'reports', 'Somente leitura', 'Opções Alterar Excluir'],
          ],
        )
      end
    end

    context 'when a resource has a translated name' do
      let!(:users_resource) { create(:resource, name: 'Cadastro de usuários', slug: 'users') }

      scenario 'lists the resource with the translation of its slug' do
        visit resources_path

        expect(Resource.count).to eq(1)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Identificador', 'Permite edição', 'Ações'],
            ['Usuários', 'users', 'Leitura e edição', 'Opções Alterar Excluir'],
          ],
        )
      end
    end

    context 'when creating a resource' do
      scenario 'creates a writable resource' do
        visit resources_path
        click_on 'Novo Recurso'

        expect(page).to have_current_path(new_resource_path)

        fill_in 'Nome', with: 'Fretes'
        fill_in 'Identificador', with: 'freights'

        expect { click_on 'Cadastrar Recurso' }.to change(Resource, :count).by(1)

        expect(page).to have_current_path(resources_path)
        expect(page).to have_text('Recurso cadastrado com sucesso.')

        resource = Resource.last
        expect(resource.name).to eq('Fretes')
        expect(resource.slug).to eq('freights')
        expect(resource.writable).to be(true)
      end

      scenario 'creates a read only resource' do
        visit new_resource_path
        fill_in 'Nome', with: 'Relatórios'
        fill_in 'Identificador', with: 'reports'
        uncheck 'Permite edição'

        expect { click_on 'Cadastrar Recurso' }.to change(Resource, :count).by(1)

        resource = Resource.last
        expect(resource.name).to eq('Relatórios')
        expect(resource.slug).to eq('reports')
        expect(resource.writable).to be(false)
      end

      scenario 'shows the errors of the required fields' do
        visit new_resource_path

        expect { click_on 'Cadastrar Recurso' }.not_to change(Resource, :count)

        expect(page).to have_text('Nome não pode ficar em branco')
        expect(page).to have_text('Identificador não pode ficar em branco')
      end

      scenario 'does not accept a slug outside the expected format' do
        visit new_resource_path
        fill_in 'Nome', with: 'Fretes'
        fill_in 'Identificador', with: 'Meus Fretes'

        expect { click_on 'Cadastrar Recurso' }.not_to change(Resource, :count)

        expect(page).to have_text('Identificador deve começar com uma letra minúscula e conter apenas letras minúsculas, ' \
                                  'números e _')
      end

      context 'when the slug is already taken' do
        let!(:existing_resource) { create(:resource, name: 'Fretes', slug: 'freights') }

        scenario 'shows the validation message' do
          visit new_resource_path
          fill_in 'Nome', with: 'Outros Fretes'
          fill_in 'Identificador', with: 'freights'

          expect { click_on 'Cadastrar Recurso' }.not_to change(Resource, :count)

          expect(page).to have_text('Identificador já está em uso por outro recurso')
        end
      end
    end

    context 'when editing a resource' do
      let!(:resource) { create(:resource, name: 'Fretes', slug: 'freights', writable: true) }

      scenario 'updates the resource data' do
        visit resources_path
        within("#resource_#{resource.id} .inline-actions") { click_on 'Alterar' }

        expect(page).to have_current_path(edit_resource_path(resource))
        expect(page).to have_field('Identificador', with: 'freights')

        fill_in 'Nome', with: 'Fretes e Viagens'
        uncheck 'Permite edição'

        expect { click_on 'Salvar Alterações' }.not_to change(Resource, :count)

        expect(page).to have_current_path(resources_path)
        expect(page).to have_text('Recurso atualizado com sucesso.')

        resource.reload
        expect(resource.name).to eq('Fretes e Viagens')
        expect(resource.slug).to eq('freights')
        expect(resource.writable).to be(false)
      end

      scenario 'shows the errors when the name is removed' do
        visit edit_resource_path(resource)
        fill_in 'Nome', with: ''
        click_on 'Salvar Alterações'

        expect(page).to have_text('Nome não pode ficar em branco')
        expect(resource.reload.name).to eq('Fretes')
      end
    end

    context 'when removing a resource' do
      let!(:resource) { create(:resource, name: 'Fretes', slug: 'freights') }

      scenario 'removes the resource' do
        visit resources_path

        expect(page).to have_css("#resource_#{resource.id} a[data-turbo-confirm='Tem certeza que deseja excluir este recurso?']")

        expect { page.driver.submit :delete, resource_path(resource), {} }.to change(Resource, :count).by(-1)

        expect(page).to have_current_path(resources_path)
        expect(page).to have_text('Recurso excluído com sucesso.')
      end
    end

    context 'when a user has permissions on the resource' do
      let!(:resource) { create(:resource, name: 'Fretes', slug: 'freights') }
      let!(:access) { create(:access, user: create(:user, tenant:), resource:) }

      scenario 'keeps the resource and explains why' do
        expect { page.driver.submit :delete, resource_path(resource), {} }.not_to change(Resource, :count)

        expect(page).to have_current_path(resources_path)
        expect(page).to have_text('Não é possível excluir um recurso com permissões vinculadas a usuários.')
      end
    end

    context 'when the resource does not exist' do
      scenario 'renders the not found page' do
        visit edit_resource_path(id: 0)

        expect(page.status_code).to eq(404)
      end
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }
    let!(:resource) { create(:resource, name: 'Fretes', slug: 'freights', writable: true) }

    before { login_as(admin, scope: :user) }

    scenario 'lists the resources without the management actions' do
      visit resources_path

      expect(Resource.count).to eq(1)
      expect(html_table_to_rows).to eq(
        [
          ['Nome', 'Identificador', 'Permite edição', 'Ações'],
          ['Fretes', 'freights', 'Leitura e edição', ''],
        ],
      )
      expect(page).to have_no_link('Novo Recurso')
    end

    scenario 'is denied when opening the edit screen' do
      visit edit_resource_path(resource)

      expect(page).to have_current_path(root_path)
      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end

    scenario 'cannot create a resource through a forged request' do
      expect do
        page.driver.submit :post, resources_path, { resource: { name: 'Viagens', slug: 'trips', writable: '1' } }
      end.not_to change(Resource, :count)

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end

    scenario 'cannot remove a resource through a forged request' do
      expect { page.driver.submit :delete, resource_path(resource), {} }.not_to change(Resource, :count)

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Fábio Operador') }
    let!(:resource) { create(:resource, name: 'Fretes', slug: 'freights') }

    before { login_as(operator, scope: :user) }

    scenario 'is denied when opening the listing' do
      visit resources_path

      expect(page).to have_current_path(root_path)
      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end

    scenario 'cannot remove a resource through a forged request' do
      expect { page.driver.submit :delete, resource_path(resource), {} }.not_to change(Resource, :count)

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:owner) { create(:user, tenant:, name: 'Arthur Dono', user_type: :owner) }
    let!(:resource) { create(:resource, name: 'Fretes', slug: 'freights') }

    before { login_as(owner, scope: :user) }

    scenario 'keeps the essential columns and collapses the actions into a menu' do
      visit resources_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'NOME')
      expect(page).to have_no_css('th', text: 'IDENTIFICADOR')

      within("#resource_#{resource.id}") do
        expect(page).to have_no_css('.inline-actions')
        click_button 'Opções'
        click_on 'Alterar'
      end

      expect(page).to have_current_path(edit_resource_path(resource))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
