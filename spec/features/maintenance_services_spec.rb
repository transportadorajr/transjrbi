require 'rails_helper'

describe 'Maintenance services', :maintenance do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Serviços da manutenção', slug: 'maintenance_services') }
  let!(:maintenance_resource) { create(:resource, name: 'Módulo de manutenção', slug: 'maintenance', writable: false) }

  context 'when the maintenance flag is off' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'does not open the listing' do
      visit maintenance_services_path

      expect(page.status_code).to eq(404)
    end
  end

  context 'when the owner is signed in', flipper: :maintenance do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are services' do
      let!(:grinding) { create(:maintenance_service, tenant:, code: 'RET-01', description: 'RETÍFICA DE MOTOR', price_cents: 850_000) }
      let!(:alignment) { create(:maintenance_service, tenant:, description: 'ALINHAMENTO', price_cents: 0, active: false) }
      let!(:stranger) { create(:maintenance_service, tenant: other_tenant, description: 'SERVIÇO DE OUTRA') }

      scenario 'lists the services from the maintenance menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Serviços'
        end

        expect(page).to have_current_path(maintenance_services_path)
        expect(MaintenanceService.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Código', 'Descrição', 'Valor de referência', 'Ativo', 'Ações'],
            ['-', 'ALINHAMENTO', 'R$ 0,00', 'Inativo', 'Opções Alterar Ativar'],
            ['RET-01', 'RETÍFICA DE MOTOR', 'R$ 8.500,00', 'Ativo', 'Opções Alterar Inativar'],
          ],
        )
        expect(page).to have_link('Novo Serviço', href: new_maintenance_service_path)
        expect(page).to have_no_text('SERVIÇO DE OUTRA')
      end

      scenario 'filters the services by code or description' do
        visit maintenance_services_path
        fill_in 'Código ou descrição', with: 'motor'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows.drop(1).map(&:second)).to eq(['RETÍFICA DE MOTOR'])
      end

      scenario 'edits a service' do
        visit maintenance_services_path
        within("#maintenance_service_#{alignment.id} .inline-actions") { click_on 'Alterar' }

        fill_in 'Valor de referência', with: '180,00'
        check 'Ativo'

        expect { click_on 'Salvar Alterações' }.not_to change(MaintenanceService, :count)

        expect(page).to have_current_path(maintenance_services_path)
        expect(page).to have_text('Serviço atualizado com sucesso.')
        expect(alignment.reload).to have_attributes(code: nil, description: 'ALINHAMENTO', price_cents: 18_000, active: true)
      end

      scenario 'does not edit a service of another tenant' do
        visit edit_maintenance_service_path(stranger)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when changing the status of a service' do
      let!(:active_service) { create(:maintenance_service, tenant:, description: 'RETÍFICA DE MOTOR') }
      let!(:inactive_service) { create(:maintenance_service, tenant:, description: 'ALINHAMENTO', active: false) }
      let!(:stranger_service) { create(:maintenance_service, tenant: other_tenant, description: 'SERVIÇO DE OUTRA') }

      scenario 'offers the toggle that matches the status of each service' do
        visit maintenance_services_path

        expect(MaintenanceService.count).to eq(3)
        expect(page).to have_link('Inativar', href: deactivate_maintenance_service_path(active_service))
        expect(page).to have_link('Ativar', href: activate_maintenance_service_path(inactive_service))
      end

      scenario 'deactivates an active service from the listing' do
        visit maintenance_services_path

        expect { page.driver.submit :patch, deactivate_maintenance_service_path(active_service), {} }.not_to change(MaintenanceService, :count)

        expect(page).to have_current_path(maintenance_services_path)
        expect(page).to have_text('Registro inativado com sucesso.')
        expect(active_service.reload).not_to be_active
      end

      scenario 'activates an inactive service from the listing' do
        visit maintenance_services_path

        expect { page.driver.submit :patch, activate_maintenance_service_path(inactive_service), {} }.not_to change(MaintenanceService, :count)

        expect(page).to have_current_path(maintenance_services_path)
        expect(page).to have_text('Registro ativado com sucesso.')
        expect(inactive_service.reload).to be_active
      end

      scenario 'does not change the status of a service of another tenant' do
        page.driver.submit :patch, deactivate_maintenance_service_path(stranger_service), {}

        expect(page.status_code).to eq(404)
        expect(stranger_service.reload).to be_active
      end
    end

    context 'when creating a service' do
      let!(:grinding) { create(:maintenance_service, tenant:, description: 'RETÍFICA DE MOTOR') }

      scenario 'creates a service' do
        visit new_maintenance_service_path

        fill_in 'Código', with: 'bal-1'
        fill_in 'Descrição', with: 'Balanceamento'
        fill_in 'Valor de referência', with: '90,00'

        expect { click_on 'Cadastrar' }.to change(MaintenanceService, :count).by(1)

        expect(page).to have_current_path(maintenance_services_path)
        expect(page).to have_text('Serviço cadastrado com sucesso.')
        expect(MaintenanceService.last).to have_attributes(tenant:, code: 'BAL-1', description: 'BALANCEAMENTO', price_cents: 9_000,
                                                           active: true)
      end

      scenario 'shows the error of a description already registered' do
        visit new_maintenance_service_path

        fill_in 'Descrição', with: 'retífica de motor'

        expect { click_on 'Cadastrar' }.not_to change(MaintenanceService, :count)

        expect(page).to have_text('Descrição já está cadastrado')
      end
    end
  end

  context 'when a user without access to the services is signed in', flipper: :maintenance do
    let!(:operator) { create(:user, tenant:) }
    let!(:maintenance_access) { create(:access, user: operator, resource: maintenance_resource, creates: false) }

    before { login_as(operator, scope: :user) }

    scenario 'cannot open the listing nor create a service' do
      visit maintenance_services_path

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')

      expect do
        page.driver.submit :post, maintenance_services_path, { maintenance_service: { description: 'SOLDA' } }
      end.not_to change(MaintenanceService, :count)
    end
  end
end
