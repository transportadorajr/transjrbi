require 'rails_helper'

describe 'Expenses' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Despesas', slug: 'expenses', writable: false) }

  context 'without a signed in user' do
    let!(:expense) { create(:atua_expense, tenant:) }

    scenario 'redirects the listing to the login screen' do
      visit expenses_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'redirects the details to the login screen' do
      visit expense_path(expense)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when there are no expenses' do
      scenario 'shows the empty state message' do
        visit expenses_path

        expect(Atua::Expense.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are expenses' do
      let!(:truck) { create(:atua_vehicle, tenant:, plate: 'EXU0F72') }
      let!(:fuel) do
        create(:atua_expense, tenant:, code: 590_101, posted_at: Time.zone.local(2026, 10, 1, 9, 18), posted_on: Date.new(2026, 10, 1),
                              history_code: 434, history_name: 'COMBUSTIVEL - DIESEL', payee_name: 'POSTO TREVO LTDA',
                              plate: 'EXU0F72', total_cents: 725_000, cost_object: truck)
      end
      let!(:unload) do
        create(:atua_expense, tenant:, code: 590_102, posted_at: Time.zone.local(2026, 10, 13, 15, 0), posted_on: Date.new(2026, 10, 13),
                              history_code: 520, history_name: 'DESCARGA - CHAPA', payee_name: nil, plate: nil, total_cents: 35_000)
      end
      let!(:removed) do
        create(:atua_expense, tenant:, code: 590_103, history_code: 999, history_name: 'MULTA', removed_from_atua_at: Time.current)
      end
      let!(:stranger) do
        create(:atua_expense, tenant: other_tenant, code: 590_104, history_code: 777, history_name: 'PEDAGIO')
      end

      scenario 'lists the active expenses of the tenant from the registrations menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Despesas'
        end

        expect(page).to have_current_path(expenses_path)
        expect(Atua::Expense.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            ['Histórico', 'Lançado em', 'Favorecido', 'Placa', 'Alocação', 'Valor total', 'Ações'],
            ['DESCARGA - CHAPA Lançamento 590102', '13/10/2026', '-', '-', 'Despesa geral', 'R$ 350,00', ''],
            ['COMBUSTIVEL - DIESEL Lançamento 590101', '01/10/2026', 'POSTO TREVO LTDA', 'EXU0F72', 'Veículo', 'R$ 7.250,00', ''],
          ],
        )
        expect(page).to have_text('2 registros')
        expect(page).to have_link(href: expense_path(fuel), title: 'Visualizar')
        expect(page).to have_no_text('MULTA')
        expect(page).to have_no_text('PEDAGIO')
      end

      scenario 'offers only the histories of the active expenses of the tenant' do
        visit expenses_path

        expect(page).to have_select('Histórico', options: ['Todos', 'COMBUSTIVEL - DIESEL', 'DESCARGA - CHAPA'])
      end

      scenario 'filters the expenses by history' do
        visit expenses_path
        select 'DESCARGA - CHAPA', from: 'Histórico'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Histórico', 'Lançado em', 'Favorecido', 'Placa', 'Alocação', 'Valor total', 'Ações'],
            ['DESCARGA - CHAPA Lançamento 590102', '13/10/2026', '-', '-', 'Despesa geral', 'R$ 350,00', ''],
          ],
        )
      end

      scenario 'filters the expenses by payee and plate' do
        visit expenses_path
        fill_in 'Favorecido', with: 'trevo'
        fill_in 'Placa', with: 'exu-0f72'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Histórico', 'Lançado em', 'Favorecido', 'Placa', 'Alocação', 'Valor total', 'Ações'],
            ['COMBUSTIVEL - DIESEL Lançamento 590101', '01/10/2026', 'POSTO TREVO LTDA', 'EXU0F72', 'Veículo', 'R$ 7.250,00', ''],
          ],
        )
      end

      scenario 'filters the expenses by allocation' do
        visit expenses_path
        select 'Despesa geral', from: 'Alocação'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Histórico', 'Lançado em', 'Favorecido', 'Placa', 'Alocação', 'Valor total', 'Ações'],
            ['DESCARGA - CHAPA Lançamento 590102', '13/10/2026', '-', '-', 'Despesa geral', 'R$ 350,00', ''],
          ],
        )
      end

      scenario 'filters the expenses by posting period' do
        visit expenses_path
        fill_in 'Lançadas a partir de', with: '2026-10-10'
        fill_in 'Lançadas até', with: '2026-10-31'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Histórico', 'Lançado em', 'Favorecido', 'Placa', 'Alocação', 'Valor total', 'Ações'],
            ['DESCARGA - CHAPA Lançamento 590102', '13/10/2026', '-', '-', 'Despesa geral', 'R$ 350,00', ''],
          ],
        )
      end

      scenario 'does not show an expense removed from Atua' do
        visit expense_path(removed)

        expect(page.status_code).to eq(404)
      end

      scenario 'does not show an expense of another tenant' do
        visit expense_path(stranger)

        expect(page.status_code).to eq(404)
      end

      scenario 'has no route to create an expense' do
        expect { page.driver.submit :post, expenses_path, {} }.not_to change(Atua::Expense, :count)

        expect(page.status_code).to eq(404)
      end

      scenario 'has no route to remove an expense' do
        expect { page.driver.submit :delete, expense_path(fuel), {} }.not_to change(Atua::Expense, :count)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when an expense belongs to a freight' do
      let!(:transport_document) do
        create(:atua_transport_document, tenant:, number: '74512', plate: 'EXU0F72', trailer_plate: 'BEV4G50')
      end
      let!(:toll) do
        create(:atua_expense, tenant:, code: 590_201, posted_on: Date.new(2026, 10, 2), history_name: 'PEDAGIO', plate: 'EXU0F72',
                              total_cents: 15_000, cost_object: transport_document)
      end

      before { create(:atua_expense, tenant:, code: 590_202, history_name: 'ALUGUEL', plate: nil) }

      scenario 'finds the expense by the plate of the trailer that pulled the freight' do
        visit expenses_path
        fill_in 'Placa', with: 'BEV4G50'
        click_on 'Aplicar Filtros'

        expect(Atua::Expense.count).to eq(2)
        expect(html_table_to_rows).to eq(
          [
            ['Histórico', 'Lançado em', 'Favorecido', 'Placa', 'Alocação', 'Valor total', 'Ações'],
            ['PEDAGIO Lançamento 590201', '02/10/2026', '-', 'EXU0F72', 'Frete', 'R$ 150,00', ''],
          ],
        )
      end
    end

    context 'when an expense has every detail' do
      let!(:registration_resources) do
        { customers: 'Clientes', vehicles: 'Veículos', drivers: 'Motoristas', transport_documents: 'CT-es' }.map do |slug, name|
          create(:resource, name:, slug:, writable: false)
        end
      end
      let!(:payee) { create(:atua_customer, tenant:, code: 1951, name: 'POSTO TREVO LTDA', document: '12.345.678/0001-90') }
      let!(:vehicle) { create(:atua_vehicle, tenant:, plate: 'EXU0F72') }
      let!(:transport_document) { create(:atua_transport_document, tenant:, code: 80_512, number: '74512') }
      let!(:expense) do
        create(:atua_expense, tenant:, code: 590_101, history_code: 434, history_name: 'COMBUSTIVEL - DIESEL',
                              description: 'ABASTECIMENTO VIAGEM 2500653', posted_at: Time.zone.local(2026, 10, 1, 9, 18),
                              accounting_on: Date.new(2026, 10, 2), settled_on: Date.new(2026, 10, 5), spending_kind: 'Variável',
                              cash_account_name: 'CAIXA MATRIZ', branch_name: 'JR TRANSPORTES', headquarters_name: 'JR HOLDING',
                              accounting_account: '4.1.01', accounting_classification: '410101', payee_code: 1951,
                              payee_name: 'POSTO TREVO LTDA', payee_document: '12.345.678/0001-90', document_model: 'NFC-e',
                              document_number: '88123', document_series: '1', document_key: '31261012345678000190650010000881231000881230',
                              document_on: Date.new(2026, 9, 30), installment_count: 1, apportionment_count: 2,
                              attachment_at: Time.zone.local(2026, 10, 1, 10, 0), plate: 'EXU0F72', vehicle_model: 'VOLVO FH 540',
                              trip_number: '2500653', trip_driver_code: 760, trip_driver_name: 'JOSE DA SILVA',
                              trip_departure_on: Date.new(2026, 9, 29), trip_arrival_on: Date.new(2026, 10, 3),
                              trip_expense_kind: 'Combustível', transport_document_code: 80_512, transport_document_number: '74512',
                              cost_object: transport_document,
                              amount_cents: 725_000, discount_cents: 5_000, total_cents: 720_000, net_amount_cents: 700_000,
                              withholdings_cents: 20_000, paid_cents: 700_000, icms_cents: 86_400, icms_credit_cents: 86_400,
                              icms_credit_percentage: BigDecimal('12'), pis_credit_cents: 11_880, cofins_credit_cents: 54_720)
      end

      scenario 'shows every detail of the expense' do
        visit expenses_path
        click_on 'COMBUSTIVEL - DIESEL'

        expect(page).to have_current_path(expense_path(expense))
        expect(page).to have_css('h1.page-title', text: 'Despesa 590101')
        expect(dl_to_hash('#expense_data')).to eq(
          'Código' => '590101',
          'Histórico' => 'COMBUSTIVEL - DIESEL',
          'Complemento' => 'ABASTECIMENTO VIAGEM 2500653',
          'Lançado em' => '01/10/2026 09:18',
          'Data contábil' => '02/10/2026',
          'Quitado em' => '05/10/2026',
          'Tipo de gasto' => 'Variável',
          'Caixa financeiro' => 'CAIXA MATRIZ',
          'Filial' => 'JR TRANSPORTES',
          'Matriz' => 'JR HOLDING',
          'Conta contábil' => '4.1.01',
          'Classificação contábil' => '410101',
        )
        expect(dl_to_hash('#document_data')).to eq(
          'Favorecido' => 'POSTO TREVO LTDA',
          'Modelo do documento' => 'NFC-e',
          'Documento/Série' => '88123/1',
          'Chave do documento' => '31261012345678000190650010000881231000881230',
          'Data do documento' => '30/09/2026',
          'Parcelas' => '1',
          'Rateios' => '2',
          'Anexo' => 'Sim',
        )
        expect(dl_to_hash('#trip_data')).to eq(
          'Placa' => 'EXU0F72',
          'Modelo do veículo' => 'VOLVO FH 540',
          'Viagem' => '2500653',
          'Motorista da viagem' => 'JOSE DA SILVA',
          'Saída da viagem' => '29/09/2026',
          'Chegada da viagem' => '03/10/2026',
          'Despesa da viagem' => 'Combustível',
          'CT-e' => '74512',
          'Alocação' => 'Frete',
        )
        expect(dl_to_hash('#values')).to eq(
          'Valor do lançamento' => 'R$ 7.250,00',
          'Desconto' => 'R$ 50,00',
          'Valor total' => 'R$ 7.200,00',
          'Valor líquido' => 'R$ 7.000,00',
          'Retenções' => 'R$ 200,00',
          'Valor pago' => 'R$ 7.000,00',
          'ICMS' => 'R$ 864,00',
          'Crédito de ICMS' => 'R$ 864,00',
          'Alíquota do crédito de ICMS' => '12,00%',
          'Crédito de PIS' => 'R$ 118,80',
          'Crédito de COFINS' => 'R$ 547,20',
        )
      end

      scenario 'links the payee, the vehicle, the driver and the transport document' do
        visit expense_path(expense)

        expect(page).to have_link('POSTO TREVO LTDA', href: customer_path(payee))
        expect(page).to have_link('EXU0F72', href: vehicle_path(vehicle))
        expect(page).to have_link('JOSE DA SILVA', href: driver_path(760))
        expect(page).to have_link('74512', href: transport_document_path(transport_document))
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:vehicle) { create(:atua_vehicle, tenant:, plate: 'EXU0F72') }
    let!(:expense) do
      create(:atua_expense, tenant:, history_name: 'COMBUSTIVEL - DIESEL', plate: 'EXU0F72', trip_driver_code: 760,
                            trip_driver_name: 'JOSE DA SILVA')
    end

    before { login_as(operator, scope: :user) }

    context 'without access to the expenses' do
      scenario 'is sent back with an access denied message' do
        visit expenses_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end

      scenario 'cannot open an expense' do
        visit expense_path(expense)

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the expenses' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'lists and opens the expenses' do
        visit expenses_path

        expect(Atua::Expense.count).to eq(1)
        expect(html_table_to_rows.size).to eq(2)

        click_on 'COMBUSTIVEL - DIESEL'

        expect(page).to have_current_path(expense_path(expense))
      end

      scenario 'does not link the vehicle and the driver without access to them' do
        visit expense_path(expense)

        expect(page).to have_css('#trip_data', text: 'EXU0F72')
        expect(page).to have_css('#trip_data', text: 'JOSE DA SILVA')
        expect(page).to have_no_link('EXU0F72')
        expect(page).to have_no_link('JOSE DA SILVA')
      end
    end
  end

  context 'on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:expense) { create(:atua_expense, tenant:, history_name: 'COMBUSTIVEL - DIESEL') }

    before do
      login_as(admin, scope: :user)
      use_mobile_screen
    end

    scenario 'keeps only the essential columns without horizontal scroll' do
      visit expenses_path

      expect(page).to have_link('COMBUSTIVEL - DIESEL')
      expect(page).to have_no_css('th', text: 'Favorecido')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
