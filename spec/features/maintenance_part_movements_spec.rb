require 'rails_helper'

describe 'Maintenance part movements', :maintenance do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Peças da manutenção', slug: 'maintenance_parts') }
  let!(:maintenance_resource) { create(:resource, name: 'Módulo de manutenção', slug: 'maintenance', writable: false) }
  let!(:lining) { create(:maintenance_part, tenant:, code: 'LF-123', description: 'LONA DE FREIO', unit: 'UN', quantity: 4) }
  let!(:oil) { create(:maintenance_part, tenant:, description: 'ÓLEO 15W40', unit: 'L', quantity: 20, unit_price_cents: 2_890) }
  let!(:supplier) { create(:supplier, tenant:, name: 'AUTO PEÇAS VALE') }

  before { travel_to(Time.zone.local(2026, 11, 17, 10)) }

  context 'when the owner is signed in', flipper: :maintenance do
    let!(:owner) { create(:user, tenant:, user_type: :owner, name: 'ANA ESTOQUE') }

    before { login_as(owner, scope: :user) }

    context 'when there are movements' do
      let!(:order) { create(:maintenance_order, tenant:, number: 12) }
      let!(:entry) do
        create(:maintenance_part_movement, maintenance_part: lining, movement_type: :entry, moved_on: Date.new(2026, 11, 10), quantity: 6,
                                           balance: 6, supplier:, invoice_number: '4512', created_by: owner)
      end
      let!(:exit_movement) do
        create(:maintenance_part_movement, maintenance_part: lining, movement_type: :exit, moved_on: Date.new(2026, 11, 12), quantity: -2,
                                           balance: 4, maintenance_order: order)
      end
      let!(:stranger) { create(:maintenance_part_movement, maintenance_part: create(:maintenance_part, tenant: other_tenant)) }

      scenario 'lists the movements from the maintenance menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Peças e Estoque'
        end
        within('#maintenance_stock_tabs') { click_on 'Movimentações' }

        expect(page).to have_current_path(maintenance_part_movements_path)
        expect(MaintenancePartMovement.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Data', 'Peça', 'Tipo', 'Quantidade', 'Saldo', 'Origem', 'Responsável'],
            ['12/11/2026', 'LF-123 - LONA DE FREIO', 'Saída', '-2 UN', '4 UN', 'OS nº 12', '-'],
            ['10/11/2026', 'LF-123 - LONA DE FREIO', 'Entrada', '+6 UN', '6 UN', 'NF 4512 · AUTO PEÇAS VALE', 'ANA ESTOQUE'],
          ],
        )
        expect(page).to have_link('OS nº 12', href: maintenance_order_path(order))
      end

      scenario 'filters the movements by type and period' do
        visit maintenance_part_movements_path
        select 'Entrada', from: 'Tipo'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows.drop(1).map(&:third)).to eq(['Entrada'])

        visit maintenance_part_movements_path(start_date: '2026-11-11', end_date: '2026-11-30')

        expect(html_table_to_rows.drop(1).map(&:third)).to eq(['Saída'])
      end

      scenario 'opens the movements of a part from the parts listing' do
        visit maintenance_parts_path
        within("#maintenance_part_#{lining.id} .inline-actions") { click_on 'Movimentações' }

        expect(page).to have_current_path(maintenance_part_movements_path(maintenance_part_id: lining.id))
        expect(html_table_to_rows.drop(1).map(&:second).uniq).to eq(['LF-123 - LONA DE FREIO'])
      end
    end

    scenario 'registers an entry raising the balance and the suggested price', :js do
      visit maintenance_part_movements_path
      click_on 'Nova Entrada'

      within('#movement_part_select') do
        find('.select2-trigger').click
        find('.select2-option', text: 'ÓLEO 15W40 (saldo: 20 L)').click
      end
      fill_in 'Quantidade', with: '12,5'
      fill_in 'Custo unitário', with: '3100'
      fill_in 'Nº da NF', with: '889'
      select 'AUTO PEÇAS VALE', from: 'Fornecedor'

      expect { click_on 'Registrar Entrada' }.to change(MaintenancePartMovement, :count).by(1)

      expect(page).to have_text('Entrada registrada com sucesso.')
      expect(MaintenancePartMovement.last).to have_attributes(tenant:, maintenance_part: oil, movement_type: 'entry', quantity: 12.5,
                                                              balance: 32.5, moved_on: Date.new(2026, 11, 17), unit_cost_cents: 3_100,
                                                              supplier:, invoice_number: '889', created_by: owner)
      expect(oil.reload).to have_attributes(quantity: 32.5, unit_price_cents: 3_100)
    end

    scenario 'registers an adjustment setting the counted balance' do
      visit new_maintenance_part_movement_path(movement_type: :adjustment)

      find('input[name="maintenance_part_movement[maintenance_part_id]"]', visible: false).set(lining.id)
      fill_in 'Quantidade contada', with: '3'
      fill_in 'Observação', with: 'Inventário de novembro'

      expect { click_on 'Registrar Ajuste' }.to change(MaintenancePartMovement, :count).by(1)

      expect(page).to have_text('Ajuste registrado com sucesso.')
      expect(MaintenancePartMovement.last).to have_attributes(maintenance_part: lining, movement_type: 'adjustment', quantity: -1, balance: 3,
                                                              notes: 'Inventário de novembro', unit_cost_cents: nil)
      expect(lining.reload.quantity).to eq(3)
    end

    scenario 'shows the errors of an incomplete adjustment' do
      visit new_maintenance_part_movement_path(movement_type: :adjustment)

      find('input[name="maintenance_part_movement[maintenance_part_id]"]', visible: false).set(lining.id)
      fill_in 'Quantidade contada', with: '4'

      expect { click_on 'Registrar Ajuste' }.not_to change(MaintenancePartMovement, :count)

      expect(page).to have_text('Quantidade é igual ao saldo atual da peça')
      expect(page).to have_text('Observação não pode ficar em branco')
      expect(lining.reload.quantity).to eq(4)
    end

    scenario 'does not register a movement of a part of another tenant' do
      stranger_part = create(:maintenance_part, tenant: other_tenant, quantity: 1)

      expect do
        page.driver.submit :post, maintenance_part_movements_path,
                           { maintenance_part_movement: { movement_type: 'entry', maintenance_part_id: stranger_part.id,
                                                          moved_on: '2026-11-17', quantity: '5' } }
      end.not_to change(MaintenancePartMovement, :count)

      expect(page.status_code).to eq(422)
      expect(stranger_part.reload.quantity).to eq(1)
    end

    context 'when the screen is opened on a phone', :js do
      let!(:entry) { create(:maintenance_part_movement, maintenance_part: lining, quantity: 4, balance: 4, moved_on: Date.new(2026, 11, 10)) }

      scenario 'keeps the essential columns and fits the screen' do
        use_mobile_screen
        visit maintenance_part_movements_path

        expect(html_table_to_rows).to eq([%w[DATA PEÇA QUANTIDADE], ['10/11/2026', 'LF-123 - LONA DE FREIO', '+4 UN']])
        expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      end
    end
  end

  context 'when a user can only read the parts', flipper: :maintenance do
    let!(:reader) { create(:user, tenant:) }
    let!(:access) { create(:access, user: reader, resource:, reads: true, creates: false) }
    let!(:maintenance_access) { create(:access, user: reader, resource: maintenance_resource, creates: false) }

    before { login_as(reader, scope: :user) }

    scenario 'sees the movements without the options to register them' do
      visit maintenance_part_movements_path

      expect(page).to have_css('#maintenance_stock_tabs .nav-link.active', text: 'Movimentações')
      expect(page).to have_no_link('Nova Entrada')
      expect(page).to have_no_link('Ajuste de Estoque')

      visit new_maintenance_part_movement_path

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end
  end
end
