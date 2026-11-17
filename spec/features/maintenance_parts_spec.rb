require 'rails_helper'

describe 'Maintenance parts', :maintenance do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Peças da manutenção', slug: 'maintenance_parts') }
  let!(:maintenance_resource) { create(:resource, name: 'Módulo de manutenção', slug: 'maintenance', writable: false) }

  context 'without a signed in user' do
    scenario 'redirects the listing to the login screen' do
      visit maintenance_parts_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the maintenance flag is off' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'does not open the listing' do
      visit maintenance_parts_path

      expect(page.status_code).to eq(404)
    end
  end

  context 'when the owner is signed in', flipper: :maintenance do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are no parts' do
      scenario 'shows the empty state message' do
        visit maintenance_parts_path

        expect(MaintenancePart.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are parts' do
      let!(:lining) do
        create(:maintenance_part, tenant:, code: 'LF-123', description: 'LONA DE FREIO', unit: 'UN', brand: 'FRAS-LE',
                                  unit_price_cents: 8_500, quantity: 12)
      end
      let!(:oil) { create(:maintenance_part, tenant:, description: 'ÓLEO 15W40', unit: 'L', unit_price_cents: 2_890, active: false) }
      let!(:stranger) { create(:maintenance_part, tenant: other_tenant, description: 'PEÇA DE OUTRA') }

      scenario 'lists the parts from the maintenance menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Peças e Estoque'
        end

        expect(page).to have_current_path(maintenance_parts_path)
        expect(MaintenancePart.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Código', 'Descrição', 'Unidade', 'Marca', 'Valor unitário', 'Saldo', 'Ativo', 'Ações'],
            ['LF-123', 'LONA DE FREIO', 'UN', 'FRAS-LE', 'R$ 85,00', '12 UN', 'Ativo', 'Opções Alterar Inativar Movimentações'],
            ['-', 'ÓLEO 15W40', 'L', '-', 'R$ 28,90', '0 L', 'Inativo', 'Opções Alterar Ativar Movimentações'],
          ],
        )
        expect(page).to have_link('Nova Peça', href: new_maintenance_part_path)
        expect(page).to have_css('#maintenance_stock_tabs .nav-link.active', text: 'Peças')
        expect(page).to have_link('Movimentações', href: maintenance_part_movements_path)
        expect(page).to have_no_text('PEÇA DE OUTRA')
      end

      scenario 'sorts the parts by the unit price' do
        visit maintenance_parts_path(sort: 'unit_price', direction: 'desc')

        expect(html_table_to_rows.drop(1).map(&:second)).to eq(['LONA DE FREIO', 'ÓLEO 15W40'])
      end

      scenario 'filters the parts by code or description and status' do
        visit maintenance_parts_path
        fill_in 'Código ou descrição', with: 'lf-1'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows.drop(1).map(&:second)).to eq(['LONA DE FREIO'])

        visit maintenance_parts_path
        select 'Inativo', from: 'Ativo'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows.drop(1).map(&:second)).to eq(['ÓLEO 15W40'])
      end

      scenario 'edits a part' do
        visit maintenance_parts_path
        within("#maintenance_part_#{oil.id} .inline-actions") { click_on 'Alterar' }

        fill_in 'Código', with: 'ol-1540'
        fill_in 'Marca', with: 'lubrax'
        fill_in 'Valor unitário', with: '31,50'
        check 'Ativo'

        expect { click_on 'Salvar Alterações' }.not_to change(MaintenancePart, :count)

        expect(page).to have_current_path(maintenance_parts_path)
        expect(page).to have_text('Peça atualizada com sucesso.')
        expect(oil.reload).to have_attributes(code: 'OL-1540', description: 'ÓLEO 15W40', unit: 'L', brand: 'LUBRAX',
                                              unit_price_cents: 3_150, active: true)
      end

      scenario 'does not edit a part of another tenant' do
        visit edit_maintenance_part_path(stranger)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when changing the status of a part' do
      let!(:active_part) { create(:maintenance_part, tenant:, description: 'LONA DE FREIO') }
      let!(:inactive_part) { create(:maintenance_part, tenant:, description: 'ÓLEO 15W40', active: false) }
      let!(:stranger_part) { create(:maintenance_part, tenant: other_tenant, description: 'PEÇA DE OUTRA') }

      scenario 'offers the toggle that matches the status of each part' do
        visit maintenance_parts_path

        expect(MaintenancePart.count).to eq(3)
        expect(page).to have_link('Inativar', href: deactivate_maintenance_part_path(active_part))
        expect(page).to have_link('Ativar', href: activate_maintenance_part_path(inactive_part))
      end

      scenario 'deactivates an active part from the listing' do
        visit maintenance_parts_path

        expect { page.driver.submit :patch, deactivate_maintenance_part_path(active_part), {} }.not_to change(MaintenancePart, :count)

        expect(page).to have_current_path(maintenance_parts_path)
        expect(page).to have_text('Registro inativado com sucesso.')
        expect(active_part.reload).not_to be_active
      end

      scenario 'activates an inactive part from the listing' do
        visit maintenance_parts_path

        expect { page.driver.submit :patch, activate_maintenance_part_path(inactive_part), {} }.not_to change(MaintenancePart, :count)

        expect(page).to have_current_path(maintenance_parts_path)
        expect(page).to have_text('Registro ativado com sucesso.')
        expect(inactive_part.reload).to be_active
      end

      scenario 'does not change the status of a part of another tenant' do
        page.driver.submit :patch, deactivate_maintenance_part_path(stranger_part), {}

        expect(page.status_code).to eq(404)
        expect(stranger_part.reload).to be_active
      end
    end

    context 'when creating a part' do
      let!(:lining) { create(:maintenance_part, tenant:, code: 'LF-123', description: 'LONA DE FREIO') }

      scenario 'creates a part' do
        visit maintenance_parts_path
        click_on 'Nova Peça'

        fill_in 'Código', with: 'fo-200'
        fill_in 'Descrição', with: 'Filtro de óleo'
        expect(page).to have_select('Unidade', selected: 'UN - Unidade')
        select 'PC - Peça', from: 'Unidade'
        fill_in 'Marca', with: 'Mann'
        fill_in 'Valor unitário', with: '64,90'

        expect { click_on 'Cadastrar' }.to change(MaintenancePart, :count).by(1)

        expect(page).to have_current_path(maintenance_parts_path)
        expect(page).to have_text('Peça cadastrada com sucesso.')
        expect(MaintenancePart.last).to have_attributes(tenant:, code: 'FO-200', description: 'FILTRO DE ÓLEO', unit: 'PC',
                                                        brand: 'MANN', unit_price_cents: 6_490, active: true)
      end

      scenario 'shows the errors of a code and a description already registered' do
        visit new_maintenance_part_path

        fill_in 'Código', with: 'lf-123'
        fill_in 'Descrição', with: 'lona de freio'

        expect { click_on 'Cadastrar' }.not_to change(MaintenancePart, :count)

        expect(page).to have_text('Código já está cadastrado em outra peça')
        expect(page).to have_text('Descrição já está cadastrada')
      end
    end

    context 'when the screen is opened on a phone', :js do
      let!(:lining) { create(:maintenance_part, tenant:, code: 'LF-123', description: 'LONA DE FREIO', unit_price_cents: 8_500) }

      scenario 'keeps the essential columns and fits the screen' do
        use_mobile_screen
        visit maintenance_parts_path

        expect(html_table_to_rows).to eq([%w[DESCRIÇÃO ATIVO AÇÕES], ['LONA DE FREIO', 'Ativo', 'Opções']])
        expect(page).to have_link('Ordenar por')
        expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      end
    end
  end

  context 'when a user without access to the parts is signed in', flipper: :maintenance do
    let!(:operator) { create(:user, tenant:) }
    let!(:maintenance_access) { create(:access, user: operator, resource: maintenance_resource, creates: false) }

    before { login_as(operator, scope: :user) }

    scenario 'cannot open the listing nor create a part' do
      visit maintenance_parts_path

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')

      expect do
        page.driver.submit :post, maintenance_parts_path, { maintenance_part: { description: 'FILTRO' } }
      end.not_to change(MaintenancePart, :count)
    end
  end
end
