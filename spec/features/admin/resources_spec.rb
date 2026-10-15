require 'rails_helper'

describe 'Admin resources', :admin do
  let!(:admin_user) { create(:admin_user) }

  context 'without a session' do
    let!(:resource) { create(:resource, name: 'Fretes', slug: 'freights') }

    scenario 'redirects to the admin login screen' do
      visit admin_resources_path

      expect(page).to have_current_path(admin_login_path)
    end

    scenario 'does not create a resource' do
      expect do
        page.driver.submit :post, admin_resources_path, { admin_resource: { name: 'Viagens', slug: 'trips', writable: '1' } }
      end.not_to change(Resource, :count)

      expect(page).to have_current_path(admin_login_path)
    end

    scenario 'does not remove a resource' do
      expect { page.driver.submit :delete, admin_resource_path(resource), {} }.not_to change(Resource, :count)

      expect(page).to have_current_path(admin_login_path)
    end
  end

  context 'with an app owner signed in' do
    let!(:owner) { create(:user, user_type: :owner) }

    before { sign_in owner }

    scenario 'does not reach the listing' do
      visit admin_resources_path

      expect(page).to have_current_path(admin_login_path)
    end
  end

  context 'with a signed in admin user' do
    before { sign_in_admin(admin_user) }

    context 'when there are no resources' do
      scenario 'shows the empty state message' do
        visit admin_resources_path

        expect(Resource.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are resources' do
      let!(:freight_resource) { create(:resource, name: 'Fretes', slug: 'freights', writable: true) }
      let!(:report_resource) { create(:resource, name: 'Relatórios', slug: 'reports', writable: false) }

      scenario 'lists every resource with its name, slug and writable status' do
        within('#sidebar') { click_on 'Recursos' }

        expect(page).to have_current_path(admin_resources_path)
        expect(Resource.count).to eq(2)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Identificador', 'Permite edição', 'Ações'],
            ['Fretes', 'freights', 'Leitura e edição', 'Opções Alterar Excluir'],
            ['Relatórios', 'reports', 'Somente leitura', 'Opções Alterar Excluir'],
          ],
        )
        expect(page).to have_text('2 registros')
        expect(page).to have_link('Novo Recurso', href: new_admin_resource_path)
      end

      scenario 'filters the resources by name' do
        visit admin_resources_path
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
        visit admin_resources_path(slug: 'report')

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
        visit admin_resources_path

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
        visit admin_resources_path
        click_on 'Novo Recurso'

        expect(page).to have_current_path(new_admin_resource_path)

        fill_in 'Nome', with: 'Fretes'
        fill_in 'Identificador', with: 'freights'

        expect { click_on 'Cadastrar Recurso' }.to change(Resource, :count).by(1)

        expect(page).to have_current_path(admin_resources_path)
        expect(page).to have_text('Recurso cadastrado com sucesso.')

        resource = Resource.last
        expect(resource.name).to eq('Fretes')
        expect(resource.slug).to eq('freights')
        expect(resource.writable).to be(true)
      end

      scenario 'creates a read only resource' do
        visit new_admin_resource_path
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
        visit new_admin_resource_path

        expect { click_on 'Cadastrar Recurso' }.not_to change(Resource, :count)

        expect(page).to have_text('Nome não pode ficar em branco')
        expect(page).to have_text('Identificador não pode ficar em branco')
      end

      scenario 'does not accept a slug outside the expected format' do
        visit new_admin_resource_path
        fill_in 'Nome', with: 'Fretes'
        fill_in 'Identificador', with: 'Meus Fretes'

        expect { click_on 'Cadastrar Recurso' }.not_to change(Resource, :count)

        expect(page).to have_text('Identificador deve começar com uma letra minúscula e conter apenas letras minúsculas, ' \
                                  'números e _')
      end

      context 'when the slug is already taken' do
        let!(:existing_resource) { create(:resource, name: 'Fretes', slug: 'freights') }

        scenario 'shows the validation message' do
          visit new_admin_resource_path
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
        visit admin_resources_path
        within("#resource_#{resource.id} .inline-actions") { click_on 'Alterar' }

        expect(page).to have_current_path(edit_admin_resource_path(resource))
        expect(page).to have_field('Identificador', with: 'freights')

        fill_in 'Nome', with: 'Fretes e Viagens'
        uncheck 'Permite edição'

        expect { click_on 'Salvar Alterações' }.not_to change(Resource, :count)

        expect(page).to have_current_path(admin_resources_path)
        expect(page).to have_text('Recurso atualizado com sucesso.')

        resource.reload
        expect(resource.name).to eq('Fretes e Viagens')
        expect(resource.slug).to eq('freights')
        expect(resource.writable).to be(false)
      end

      scenario 'shows the errors when the name is removed' do
        visit edit_admin_resource_path(resource)
        fill_in 'Nome', with: ''
        click_on 'Salvar Alterações'

        expect(page).to have_text('Nome não pode ficar em branco')
        expect(resource.reload.name).to eq('Fretes')
      end
    end

    context 'when removing a resource' do
      let!(:resource) { create(:resource, name: 'Fretes', slug: 'freights') }

      scenario 'removes the resource' do
        visit admin_resources_path

        expect(page).to have_css("#resource_#{resource.id} a[data-turbo-confirm='Tem certeza que deseja excluir este recurso?']")

        expect { page.driver.submit :delete, admin_resource_path(resource), {} }.to change(Resource, :count).by(-1)

        expect(page).to have_current_path(admin_resources_path)
        expect(page).to have_text('Recurso excluído com sucesso.')
      end
    end

    context 'when a user has permissions on the resource' do
      let!(:resource) { create(:resource, name: 'Fretes', slug: 'freights') }
      let!(:access) { create(:access, user: create(:user), resource:) }

      scenario 'keeps the resource and explains why' do
        expect { page.driver.submit :delete, admin_resource_path(resource), {} }.not_to change(Resource, :count)

        expect(page).to have_current_path(admin_resources_path)
        expect(page).to have_text('Não é possível excluir um recurso com permissões vinculadas a usuários.')
      end
    end

    context 'when the resource does not exist' do
      scenario 'renders the not found page' do
        visit edit_admin_resource_path(id: 0)

        expect(page.status_code).to eq(404)
      end
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:resource) { create(:resource, name: 'Fretes', slug: 'freights') }

    before { sign_in_admin(admin_user) }

    scenario 'keeps the essential columns and collapses the actions into a menu' do
      visit admin_resources_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'NOME')
      expect(page).to have_no_css('th', text: 'IDENTIFICADOR')

      within("#resource_#{resource.id}") do
        expect(page).to have_no_css('.inline-actions')
        click_button 'Opções'
        click_on 'Alterar'
      end

      expect(page).to have_current_path(edit_admin_resource_path(resource))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
