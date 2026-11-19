require 'rails_helper'

describe 'Maintenance order items', :maintenance, flipper: :maintenance do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Ordens de serviço', slug: 'maintenance_orders') }
  let!(:maintenance_resource) { create(:resource, name: 'Módulo de manutenção', slug: 'maintenance', writable: false) }
  let!(:maintenance_order) { create(:maintenance_order, tenant:, number: 7, plate: 'EXU1A23') }
  let!(:mechanic) { create(:workshop_employee, tenant:, name: 'CARLOS SOUZA') }
  let!(:supplier) { create(:supplier, tenant:, name: 'RETÍFICA IPATINGA') }

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when the order has no items' do
      scenario 'shows the empty sections and zeroed totals' do
        visit maintenance_order_path(maintenance_order)

        expect(page).to have_text('Nenhuma peça lançada nesta OS.')
        expect(page).to have_text('Nenhuma mão de obra lançada nesta OS.')
        expect(page).to have_text('Nenhum serviço terceirizado lançado nesta OS.')
        expect(dl_to_hash('#totals')).to eq('Total de peças' => 'R$ 0,00', 'Total de serviços terceirizados' => 'R$ 0,00',
                                            'Horas de mão de obra' => '0 h', 'Total da OS' => 'R$ 0,00')
      end

      scenario 'adds a part through the modal', :js do
        visit maintenance_order_path(maintenance_order)
        click_on 'Adicionar peça'

        within('#maintenance_order_item_modal') do
          expect(page).to have_text('Nova Peça ou Material')
          fill_in 'Código', with: 'lf-123'
          fill_in 'Descrição', with: 'Lona de freio'
          fill_in 'Quantidade', with: '4'
          fill_in 'Unidade', with: 'un'
          fill_in 'Valor unitário', with: '8500'
          select 'Compra direta', from: 'Origem'
          fill_in 'Nº requisição / NF', with: 'NF 4512'
          fill_in 'Observação', with: " Lado esquerdo do eixo traseiro \n"
          click_on 'Adicionar'
        end

        expect(page).to have_text('Peça adicionada à OS.')
        expect(MaintenanceOrderPart.count).to eq(1)
        expect(MaintenanceOrderPart.last).to have_attributes(tenant:, maintenance_order:, code: 'LF-123', description: 'LONA DE FREIO',
                                                             quantity: 4, unit: 'UN', source_type: 'purchase',
                                                             document_number: 'NF 4512', unit_price_cents: 8_500, total_cents: 34_000,
                                                             notes: 'Lado esquerdo do eixo traseiro')
        expect(MaintenanceOrderItem.count).to eq(1)
        expect(MaintenanceOrderItem.last).to have_attributes(tenant:, maintenance_order:, itemizable: MaintenanceOrderPart.last,
                                                             description: 'LONA DE FREIO', notes: 'Lado esquerdo do eixo traseiro',
                                                             total_cents: 34_000, position: 1)
        expect(html_table_to_rows(table: find('#parts table'))).to eq(
          [
            ['CÓDIGO', 'DESCRIÇÃO', 'QUANTIDADE', 'ORIGEM', 'Nº REQUISIÇÃO / NF', 'VALOR UNITÁRIO', 'TOTAL', 'AÇÕES'],
            ['LF-123', 'LONA DE FREIO Lado esquerdo do eixo traseiro', '4 UN', 'Compra direta', 'NF 4512', 'R$ 85,00', 'R$ 340,00', ''],
          ],
        )
        expect(maintenance_order.reload.total_cents).to eq(34_000)
      end

      scenario 'keeps the modal open with the errors of an incomplete part', :js do
        visit maintenance_order_path(maintenance_order)
        click_on 'Adicionar peça'

        within('#maintenance_order_item_modal') do
          fill_in 'Quantidade', with: '0'
          click_on 'Adicionar'

          expect(page).to have_css('.alert-danger', text: 'Descrição não pode ficar em branco e Quantidade deve ser maior que 0')
        end

        expect(MaintenanceOrderPart.count).to eq(0)
      end

      scenario 'adds a labor calculating the hours', :js do
        visit maintenance_order_path(maintenance_order)
        click_on 'Adicionar mão de obra'

        within('#maintenance_order_item_modal') do
          select 'CARLOS SOUZA', from: 'Mecânico'
          fill_in 'Data', with: Date.new(2026, 11, 11)
          fill_in 'Início', with: '08:00'
          fill_in 'Fim', with: '10:45'
          fill_in 'Atividade realizada', with: 'Troca das lonas'
          click_on 'Adicionar'
        end

        expect(page).to have_text('Mão de obra adicionada à OS.')
        expect(MaintenanceOrderLabor.count).to eq(1)
        expect(MaintenanceOrderLabor.last).to have_attributes(maintenance_order:, workshop_employee: mechanic,
                                                              worked_on: Date.new(2026, 11, 11), hours: BigDecimal('2.75'),
                                                              activity: 'Troca das lonas')
        expect(dl_to_hash('#totals')).to include('HORAS DE MÃO DE OBRA' => '2,75 h')
      end

      scenario 'adds a service without supplier', :js do
        visit maintenance_order_path(maintenance_order)
        click_on 'Adicionar serviço'

        within('#maintenance_order_item_modal') do
          fill_in 'Serviço', with: 'Troca das lonas'
          fill_in 'Valor orçado', with: '15000'
          click_on 'Adicionar'
        end

        expect(page).to have_text('Serviço terceirizado adicionado à OS.')
        expect(MaintenanceOrderService.count).to eq(1)
        expect(MaintenanceOrderService.last).to have_attributes(supplier: nil, description: 'Troca das lonas', quoted_cents: 15_000)
        expect(html_table_to_rows(table: find('#services table')).second.first).to eq('-')
      end

      scenario 'adds a service of a supplier', :js do
        visit maintenance_order_path(maintenance_order)
        click_on 'Adicionar serviço'

        within('#maintenance_order_item_modal') do
          select 'RETÍFICA IPATINGA', from: 'Fornecedor'
          fill_in 'Serviço', with: 'Retífica do tambor'
          fill_in 'Nº do orçamento', with: '77'
          fill_in 'Valor orçado', with: '45000'
          fill_in 'Observação', with: 'Entrega em 2 dias'
          click_on 'Adicionar'
        end

        expect(page).to have_text('Serviço terceirizado adicionado à OS.')
        expect(MaintenanceOrderService.count).to eq(1)
        expect(MaintenanceOrderService.last).to have_attributes(maintenance_order:, supplier:, description: 'Retífica do tambor',
                                                                quote_number: '77', quoted_cents: 45_000, approved_cents: nil,
                                                                notes: 'Entrega em 2 dias')
        expect(dl_to_hash('#totals')).to include('TOTAL DE SERVIÇOS TERCEIRIZADOS' => 'R$ 450,00', 'TOTAL DA OS' => 'R$ 450,00')
      end
    end

    context 'when the parts and services are registered' do
      let!(:lining) do
        create(:maintenance_part, tenant:, code: 'LF-123', description: 'LONA DE FREIO', unit: 'UN', unit_price_cents: 8_500)
      end
      let!(:old_lining) { create(:maintenance_part, tenant:, description: 'LONA ANTIGA', active: false) }
      let!(:stranger_part) { create(:maintenance_part, tenant: other_tenant, description: 'LONA DE OUTRA') }
      let!(:grinding) { create(:maintenance_service, tenant:, description: 'RETÍFICA DO TAMBOR', price_cents: 45_000) }

      scenario 'adds a registered part filling its fields', :js do
        visit maintenance_order_path(maintenance_order)
        click_on 'Adicionar peça'

        within('#maintenance_part_select') do
          find('.select2-trigger').click
          expect(page).to have_css('.select2-option', count: 1)
          expect(page).to have_no_css('.select2-option', text: 'LONA ANTIGA')
          find('.select2-option', text: 'LF-123 - LONA DE FREIO').click
        end

        within('#maintenance_order_item_modal') do
          expect(page).to have_field('Código', with: 'LF-123')
          expect(page).to have_field('Descrição', with: 'LONA DE FREIO')
          expect(page).to have_field('Unidade', with: 'UN')
          expect(page).to have_field('Valor unitário', with: '85,00')
          fill_in 'Quantidade', with: '2'
          select 'Estoque', from: 'Origem'
          click_on 'Adicionar'
        end

        expect(page).to have_text('Peça adicionada à OS.')
        expect(MaintenanceOrderPart.count).to eq(1)
        expect(MaintenanceOrderPart.last).to have_attributes(maintenance_part: lining, code: 'LF-123', description: 'LONA DE FREIO',
                                                             quantity: 2, unit: 'UN', unit_price_cents: 8_500, total_cents: 17_000)
      end

      scenario 'adds a registered service suggesting its reference price', :js do
        visit maintenance_order_path(maintenance_order)
        click_on 'Adicionar serviço'

        within('#maintenance_service_select') do
          find('.select2-trigger').click
          find('.select2-option', text: 'RETÍFICA DO TAMBOR').click
        end

        within('#maintenance_order_item_modal') do
          expect(page).to have_field('Valor orçado', with: '450,00')
          select 'RETÍFICA IPATINGA', from: 'Fornecedor'
          click_on 'Adicionar'
        end

        expect(page).to have_text('Serviço terceirizado adicionado à OS.')
        expect(MaintenanceOrderService.count).to eq(1)
        expect(MaintenanceOrderService.last).to have_attributes(maintenance_service: grinding, supplier:,
                                                                description: 'RETÍFICA DO TAMBOR', quoted_cents: 45_000)
        expect(MaintenanceOrderService.last.item).to have_attributes(maintenance_order:, description: 'RETÍFICA DO TAMBOR', total_cents: 45_000)
      end

      scenario 'does not add a part registered by another tenant' do
        page.driver.submit :post, maintenance_order_parts_path(maintenance_order),
                           { maintenance_order_part: { maintenance_part_id: stranger_part.id, quantity: '1', source_type: 'stock' } }

        expect(page.status_code).to eq(422)
        expect(MaintenanceOrderPart.count).to eq(0)
        expect(page.body).to include('Peça do cadastro não está cadastrada como peça ativa')
      end
    end

    context 'when the order has items' do
      let!(:part) do
        create(:maintenance_order_part, maintenance_order:, code: 'LF-123', description: 'LONA DE FREIO', quantity: 4, unit: 'UN',
                                        unit_price_cents: 8_500, total_cents: 34_000)
      end
      let!(:labor) do
        create(:maintenance_order_labor, maintenance_order:, workshop_employee: mechanic, worked_on: Date.new(2026, 11, 11),
                                         start_time: '08:00', end_time: '10:30', hours: 2.5, activity: 'Troca das lonas')
      end
      let!(:service) do
        create(:maintenance_order_service, maintenance_order:, supplier:, description: 'Retífica do tambor', quote_number: '77',
                                           quoted_cents: 45_000, approved_cents: 42_000, approved_by_name: 'MARCOS',
                                           invoice_number: '9981', notes: 'Tambor dianteiro')
      end
      let!(:stranger_order) { create(:maintenance_order, tenant: other_tenant) }
      let!(:stranger_part) { create(:maintenance_order_part, maintenance_order: stranger_order) }

      before { MaintenanceOrders::RecalculateTotalsCommand.call(maintenance_order) }

      scenario 'lists the items and the totals of the order' do
        visit maintenance_order_path(maintenance_order)

        expect(html_table_to_rows(table: find('#parts table'))).to eq(
          [
            ['Código', 'Descrição', 'Quantidade', 'Origem', 'Nº requisição / NF', 'Valor unitário', 'Total', 'Ações'],
            ['LF-123', 'LONA DE FREIO', '4 UN', 'Estoque', '-', 'R$ 85,00', 'R$ 340,00', 'Opções Alterar Excluir'],
          ],
        )
        expect(html_table_to_rows(table: find('#labors table'))).to eq(
          [
            ['Mecânico', 'Data', 'Horário', 'Horas', 'Atividade realizada', 'Ações'],
            ['CARLOS SOUZA', '11/11/2026', '08:00 às 10:30', '2,5 h', 'Troca das lonas', 'Opções Alterar Excluir'],
          ],
        )
        expect(html_table_to_rows(table: find('#services table'))).to eq(
          [
            ['Fornecedor', 'Serviço', 'Nº do orçamento', 'Valor orçado', 'Valor aprovado', 'Aprovado por', 'Nº da NF', 'Ações'],
            ['RETÍFICA IPATINGA', 'Retífica do tambor Tambor dianteiro', '77', 'R$ 450,00', 'R$ 420,00', 'MARCOS', '9981', 'Opções Alterar Excluir'],
          ],
        )
        expect(dl_to_hash('#totals')).to eq('Total de peças' => 'R$ 340,00', 'Total de serviços terceirizados' => 'R$ 420,00',
                                            'Horas de mão de obra' => '2,5 h', 'Total da OS' => 'R$ 760,00')
      end

      scenario 'opens the edit modal through a turbo stream' do
        visit edit_maintenance_order_part_path(maintenance_order, part, format: :turbo_stream)

        expect(page.status_code).to eq(200)
        expect(page.body).to include('turbo-stream action="update" target="remote-container"')
        expect(page.body).to include('Alterar Peça ou Material')
      end

      scenario 'edits a part through the modal', :js do
        visit maintenance_order_path(maintenance_order)
        within("#maintenance_order_part_#{part.id} .inline-actions") { click_on 'Alterar' }

        within('#maintenance_order_item_modal') do
          expect(page).to have_field('Quantidade', with: '4')
          fill_in 'Quantidade', with: '6'
          fill_in 'Observação', with: 'Trocar também a mola'
          click_on 'Salvar Alterações'
        end

        expect(page).to have_text('Peça atualizada.')
        expect(part.reload).to have_attributes(quantity: 6, total_cents: 51_000, notes: 'Trocar também a mola')
        expect(part.item.reload).to have_attributes(description: 'LONA DE FREIO', notes: 'Trocar também a mola', total_cents: 51_000)
        expect(maintenance_order.reload.total_cents).to eq(93_000)
      end

      scenario 'lists the parts in the order they were placed on the work order' do
        brake_shoe = create(:maintenance_order_part, maintenance_order:, code: 'SP-9', description: 'SAPATA', quantity: 2, unit: 'UN',
                                                     unit_price_cents: 1_000, total_cents: 2_000)
        brake_shoe.item.update!(position: 0)
        part.item.update!(position: 5)

        visit maintenance_order_path(maintenance_order)

        expect(html_table_to_rows(table: find('#parts table')).drop(1).map(&:first)).to eq(%w[SP-9 LF-123])
      end

      scenario 'removes a part and recalculates the totals' do
        visit maintenance_order_path(maintenance_order)

        expect do
          page.driver.submit :delete, maintenance_order_part_path(maintenance_order, part), {}
        end.to change(MaintenanceOrderPart, :count).by(-1).and change(MaintenanceOrderItem, :count).by(-1)

        expect(page).to have_current_path(maintenance_order_path(maintenance_order))
        expect(page).to have_text('Peça excluída da OS.')
        expect(maintenance_order.reload).to have_attributes(parts_total_cents: 0, total_cents: 42_000)
      end

      scenario 'counts a service by its newly approved value' do
        visit maintenance_order_path(maintenance_order)

        page.driver.submit :patch, maintenance_order_service_path(maintenance_order, service),
                           { maintenance_order_service: { description: 'Retífica do tambor', quoted: '450,00', approved: '400,00' } }

        expect(page).to have_text('Serviço terceirizado atualizado.')
        expect(service.reload.approved_cents).to eq(40_000)
        expect(service.item.reload.total_cents).to eq(40_000)
        expect(maintenance_order.reload).to have_attributes(services_total_cents: 40_000, total_cents: 74_000)
      end

      scenario 'removes a labor and a service' do
        visit maintenance_order_path(maintenance_order)

        expect do
          page.driver.submit :delete, maintenance_order_labor_path(maintenance_order, labor), {}
        end.to change(MaintenanceOrderLabor, :count).by(-1)

        expect(page).to have_text('Mão de obra excluída da OS.')

        expect do
          page.driver.submit :delete, maintenance_order_service_path(maintenance_order, service), {}
        end.to change(MaintenanceOrderService, :count).by(-1).and change(MaintenanceOrderItem, :count).by(-1)

        expect(page).to have_text('Serviço terceirizado excluído da OS.')
        expect(maintenance_order.reload).to have_attributes(services_total_cents: 0, total_cents: 34_000)
      end

      scenario 'does not remove an item of another tenant' do
        expect do
          page.driver.submit :delete, maintenance_order_part_path(stranger_order, stranger_part), {}
        end.not_to change(MaintenanceOrderPart, :count)

        expect(page.status_code).to eq(404)
      end

      scenario 'does not reach an item through another order' do
        other_order = create(:maintenance_order, tenant:)

        expect do
          page.driver.submit :delete, maintenance_order_part_path(other_order, part), {}
        end.not_to change(MaintenanceOrderPart, :count)

        expect(page.status_code).to eq(404)
      end
    end
  end

  context 'when a user can only read the maintenance orders' do
    let!(:reader) { create(:user, tenant:) }
    let!(:access) { create(:access, user: reader, resource:, reads: true, creates: false) }
    let!(:maintenance_access) { create(:access, user: reader, resource: maintenance_resource, creates: false) }
    let!(:part) { create(:maintenance_order_part, maintenance_order:) }

    before { login_as(reader, scope: :user) }

    scenario 'sees the items without the options to change them' do
      visit maintenance_order_path(maintenance_order)

      expect(page).to have_text('LONA DE FREIO')
      expect(page).to have_no_link('Adicionar peça')
      expect(page).to have_no_link('Excluir')

      expect do
        page.driver.submit :post, maintenance_order_parts_path(maintenance_order),
                           { maintenance_order_part: { description: 'FILTRO', quantity: '1' } }
      end.not_to change(MaintenanceOrderPart, :count)
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }
    let!(:part) { create(:maintenance_order_part, maintenance_order:) }

    before { login_as(owner, scope: :user) }

    scenario 'keeps the essential columns of the items and fits the screen' do
      visit maintenance_order_path(maintenance_order)
      use_mobile_screen

      within('#parts') do
        expect(page).to have_css('th', text: 'DESCRIÇÃO')
        expect(page).to have_no_css('th', text: 'ORIGEM')
      end
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
