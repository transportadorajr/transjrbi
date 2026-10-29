require 'rails_helper'

describe 'Freight expenses' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Despesas de frete', slug: 'freight_expenses', writable: false) }
  let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS', terms: ['USIMINAS']) }
  let!(:usiminas_customer) { create(:atua_customer, tenant:, code: 501, name: 'USIMINAS CUBATAO', customer_group: usiminas) }
  let!(:national) { create(:commission_rule, tenant:, customer_group: usiminas) }
  let!(:argentina) { create(:commission_rule, :argentina, tenant:, customer_group: usiminas) }

  context 'without a signed in user' do
    scenario 'redirects the listing to the login screen' do
      visit freight_expenses_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when there are no commissions' do
      scenario 'shows the empty state message' do
        visit freight_expenses_path

        expect(FreightExpense.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
        expect(page).to have_no_css('#unmatched_foreign_documents')
      end
    end

    context 'without an insurance rate' do
      scenario 'warns that the cargo insurance is not calculated' do
        visit freight_expenses_path

        expect(InsuranceRate.count).to eq(0)
        within('#missing_insurance_rate') do
          expect(page).to have_text('Nenhuma alíquota de seguro cadastrada')
          expect(page).to have_text('Sem alíquota, o seguro da carga não é calculado nos CT-es.')
        end
      end
    end

    context 'when a foreign CT-e comes with Exterior as the destination city' do
      let!(:recipient) { create(:atua_customer, tenant:, code: 701, name: 'FERROSIDER SA', city: 'EXTERIOR', state: 'EX') }
      let!(:to_exterior) do
        create(:atua_transport_document, tenant:, number: '76001', taker_code: 501, taker_name: 'USIMINAS CUBATAO',
                                         recipient_code: 701, recipient_name: 'FERROSIDER SA', issued_at: Time.zone.local(2026, 10, 5, 8),
                                         destination_city: 'EXTERIOR', destination_state: 'EX', freight_cents: 1_000_000)
      end

      before { FreightExpenses::CalculateCommissionsCommand.call(tenant) }

      scenario 'calculates the commission with the rule of the recipient instead of warning about it' do
        visit freight_expenses_path

        expect(tenant.freight_expenses.count).to eq(1)
        expect(html_table_to_rows).to eq(
          [
            ['CT-e', 'Emitido em', 'Tomador', 'Tipo', 'Regra ou custo', 'Base de cálculo', 'Taxa', 'Valor', 'Ações'],
            ['76001', '05/10/2026 08:00', 'USIMINAS CUBATAO', 'Comissão', 'Argentina', 'R$ 10.000,00', '1,30%', 'R$ 130,00', ''],
          ],
        )
        expect(page).to have_no_css('#unmatched_foreign_documents')
      end
    end

    context 'when the commissions were calculated' do
      let!(:transport_documents_resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }
      let!(:commission_rules_resource) { create(:resource, name: 'Regras de comissão', slug: 'commission_rules') }
      let!(:to_minas) do
        create(:atua_transport_document, tenant:, number: '74001', taker_code: 501, taker_name: 'USIMINAS CUBATAO',
                                         issued_at: Time.zone.local(2026, 9, 30, 10), destination_city: 'IPATINGA',
                                         destination_state: 'MG', freight_cents: 1_000_000, icms_cents: 120_000)
      end
      let!(:to_rosario) do
        create(:atua_transport_document, tenant:, number: '74002', taker_code: 501, taker_name: 'USIMINAS CUBATAO',
                                         issued_at: Time.zone.local(2026, 10, 2, 8), destination_city: 'ROSARIO',
                                         destination_state: 'EX', freight_cents: 2_000_000)
      end
      let!(:to_santiago) do
        create(:atua_transport_document, tenant:, number: '74003', taker_code: 501, issued_at: Time.zone.local(2026, 10, 3, 8),
                                         destination_city: 'SANTIAGO', destination_state: 'EX', freight_cents: 4_000_000)
      end

      before do
        FreightExpenses::CalculateCommissionsCommand.call(tenant)
        stranger_group = create(:customer_group, tenant: other_tenant)
        create(:freight_expense, tenant: other_tenant, commission_rule: create(:commission_rule, tenant: other_tenant, customer_group: stranger_group),
                                 transport_document: create(:atua_transport_document, tenant: other_tenant, number: '99999'))
      end

      scenario 'lists the commissions of the tenant from the registrations menu with the totals at the bottom' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Despesas de frete'
        end

        expect(page).to have_current_path(freight_expenses_path)
        expect(tenant.freight_expenses.count).to eq(2)
        expect(html_table_to_rows).to eq(
          [
            ['CT-e', 'Emitido em', 'Tomador', 'Tipo', 'Regra ou custo', 'Base de cálculo', 'Taxa', 'Valor', 'Ações'],
            ['74002', '02/10/2026 08:00', 'USIMINAS CUBATAO', 'Comissão', 'Argentina', 'R$ 20.000,00', '1,30%', 'R$ 260,00', ''],
            ['74001', '30/09/2026 10:00', 'USIMINAS CUBATAO', 'Comissão', 'Nacional', 'R$ 8.800,00', '2,00%', 'R$ 176,00', ''],
          ],
        )
        expect(dl_to_hash('#freight_expenses_totals')).to eq('Total das despesas' => 'R$ 436,00')
        expect(page).to have_link(href: transport_document_path(to_rosario), title: 'Visualizar')
        expect(page).to have_no_text('99999')
      end

      scenario 'warns about the foreign destination without a rule' do
        visit freight_expenses_path

        within('#unmatched_foreign_documents') do
          expect(page).to have_text('1 CT-e com destino no exterior sem regra de comissão')
          expect(page).to have_link('74003', href: transport_document_path(to_santiago))
          expect(page).to have_text('SANTIAGO/EX')
        end
      end

      scenario 'filters the commissions by number, group and period' do
        visit freight_expenses_path
        fill_in 'Número do CT-e', with: '74002'
        select 'USIMINAS', from: 'Grupo de clientes'
        fill_in 'CT-es emitidos a partir de', with: '2026-10-01'
        fill_in 'CT-es emitidos até', with: '2026-10-31'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['CT-e', 'Emitido em', 'Tomador', 'Tipo', 'Regra ou custo', 'Base de cálculo', 'Taxa', 'Valor', 'Ações'],
            ['74002', '02/10/2026 08:00', 'USIMINAS CUBATAO', 'Comissão', 'Argentina', 'R$ 20.000,00', '1,30%', 'R$ 260,00', ''],
          ],
        )
        expect(dl_to_hash('#freight_expenses_totals')).to eq('Total das despesas' => 'R$ 260,00')
      end

      scenario 'opens the transport document of a commission' do
        visit freight_expenses_path
        click_on '74001'

        expect(page).to have_current_path(transport_document_path(to_minas))
      end

      scenario 'enqueues the recalculation of every commission' do
        visit freight_expenses_path

        expect(page).to have_css("form[action='#{recalculate_freight_expenses_path}'] button[data-turbo-confirm]")

        expect { click_on 'Recalcular despesas' }.to have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id)

        expect(page).to have_current_path(freight_expenses_path)
        expect(page).to have_text('Recálculo das despesas enfileirado. Ele roda em segundo plano.')
      end

      scenario 'has no route to create, change or remove a commission' do
        expense = tenant.freight_expenses.find_by!(transport_document: to_rosario)

        expect { page.driver.submit :post, '/freight_expenses', { freight_expense: { amount_cents: 1 } } }.not_to change(FreightExpense, :count)
        expect(page.status_code).to eq(404)

        page.driver.submit :patch, "/freight_expenses/#{expense.id}", { freight_expense: { amount_cents: 1 } }
        expect(page.status_code).to eq(404)

        page.driver.submit :delete, "/freight_expenses/#{expense.id}", {}
        expect(page.status_code).to eq(404)
        expect(expense.reload.amount_cents).to eq(26_000)
      end
    end
  end

  context 'when an admin is signed in and the tonnage costs were calculated' do
    around { |example| travel_to(Time.zone.local(2026, 10, 16, 12)) { example.run } }

    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:cubatao) { create(:tonnage_rate, tenant:, customer_group: usiminas) }
    let!(:ipatinga) do
      create(:tonnage_rate, tenant:, customer_group: usiminas, nickname: nil, origin_city: 'Ipatinga', origin_state: 'MG',
                            valid_month: Date.new(2026, 7, 1), rate_cents: 860)
    end
    let!(:weighed) do
      create(:atua_transport_document, tenant:, number: '75001', taker_code: 501, taker_name: 'USIMINAS CUBATAO',
                                       issued_at: Time.zone.local(2026, 10, 5, 8), origin_city: 'CUBATÃO', origin_state: 'SP',
                                       weight_tons: BigDecimal('32.5'))
    end
    let!(:without_weight) do
      create(:atua_transport_document, tenant:, number: '75002', taker_code: 501, issued_at: Time.zone.local(2026, 10, 6, 8),
                                       origin_city: 'Cubatao', origin_state: 'SP', weight_tons: nil, weight_kg: nil)
    end

    before do
      FreightExpenses::CalculateTonnageCommand.call(tenant)
      login_as(admin, scope: :user)
    end

    scenario 'lists the tonnage cost of the transport document with its weight and rate' do
      visit freight_expenses_path

      expect(tenant.freight_expenses.tonnage.count).to eq(1)
      expect(html_table_to_rows).to eq(
        [
          ['CT-e', 'Emitido em', 'Tomador', 'Tipo', 'Regra ou custo', 'Base de cálculo', 'Taxa', 'Valor', 'Ações'],
          ['75001', '05/10/2026 08:00', 'USIMINAS CUBATAO', 'Custo por tonelada', 'Brasiltec – Cubatão/SP (Cubatão)', '32,500 t',
           'R$ 12,57/t', 'R$ 408,53', ''],
        ],
      )
      expect(dl_to_hash('#freight_expenses_totals')).to eq('Total das despesas' => 'R$ 408,53')
    end

    scenario 'filters the expenses by kind' do
      create(:freight_expense, tenant:, commission_rule: national, transport_document: create(:atua_transport_document, tenant:, number: '75003'))

      visit freight_expenses_path
      select 'Custo por tonelada', from: 'Tipo'
      click_on 'Aplicar Filtros'

      expect(html_table_to_rows.drop(1).map(&:first)).to eq(['75001'])
    end

    scenario 'warns about the transport document without weight and the outdated cost' do
      visit freight_expenses_path

      within('#missing_weight_documents') do
        expect(page).to have_text('1 CT-e sem peso com custo por tonelada')
        expect(page).to have_text('75002')
        expect(page).to have_text('Cubatao/SP')
      end
      within('#outdated_tonnage_rates') do
        expect(page).to have_text('1 custo por tonelada desatualizado')
        expect(page).to have_text('Brasiltec – Ipatinga/MG')
        expect(page).to have_text('07/2026')
      end
    end
  end

  context 'when an admin is signed in and the cargo insurance was calculated' do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:insurance_rates_resource) { create(:resource, name: 'Alíquotas de seguro', slug: 'insurance_rates') }
    let!(:insurance_rate) { create(:insurance_rate, tenant:) }
    let!(:to_minas) do
      create(:atua_transport_document, tenant:, number: '76001', taker_code: 501, taker_name: 'USIMINAS CUBATAO', destination_state: 'MG',
                                       issued_at: Time.zone.local(2026, 10, 5, 8), goods_value_cents: 838_998, freight_cents: 55_504)
    end
    let!(:to_rosario) do
      create(:atua_transport_document, tenant:, number: '76002', taker_code: 501, taker_name: 'USIMINAS CUBATAO', destination_state: 'EX',
                                       issued_at: Time.zone.local(2026, 10, 4, 8), goods_value_cents: 838_998, freight_cents: 55_504)
    end

    before do
      FreightExpenses::CalculateInsuranceCommand.call(tenant)
      login_as(admin, scope: :user)
    end

    scenario 'lists the cargo insurance of each transport document with the IOF of the international freight' do
      visit freight_expenses_path
      select 'Seguro da carga', from: 'Tipo'
      click_on 'Aplicar Filtros'

      expect(tenant.freight_expenses.insurance.count).to eq(2)
      expect(html_table_to_rows).to eq(
        [
          ['CT-e', 'Emitido em', 'Tomador', 'Tipo', 'Regra ou custo', 'Base de cálculo', 'Taxa', 'Valor', 'Ações'],
          ['76001', '05/10/2026 08:00', 'USIMINAS CUBATAO', 'Seguro da carga', 'Alíquota de seguro', 'R$ 8.945,02', '0,022%',
           'R$ 1,97', ''],
          ['76002', '04/10/2026 08:00', 'USIMINAS CUBATAO', 'Seguro da carga',
           'Alíquota de seguro (internacional, com IOF de R$ 0,15)', 'R$ 8.945,02', '0,022%', 'R$ 2,12', ''],
        ],
      )
      expect(dl_to_hash('#freight_expenses_totals')).to eq('Total das despesas' => 'R$ 4,09')
      expect(page).to have_no_css('#missing_insurance_rate')
    end

    scenario 'opens the insurance rate of the expense' do
      visit freight_expenses_path
      first(:link, 'Alíquota de seguro').click

      expect(page).to have_current_path(insurance_rate_path)
    end
  end

  context 'when an admin is signed in and the tarp lining was calculated' do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:moinho) { create(:customer_group, tenant:, name: 'MOINHO REGIO', terms: ['MOINHO REGIO'], activated_at: Time.current) }
    let!(:moinho_customer) { create(:atua_customer, tenant:, code: 601, name: 'MOINHO REGIO ALIMENTOS S/A', customer_group: moinho) }
    let!(:to_cascavel) do
      create(:atua_transport_document, tenant:, number: '77001', taker_code: 601, taker_name: 'MOINHO REGIO ALIMENTOS S/A',
                                       issued_at: Time.zone.local(2026, 10, 5, 8))
    end
    let!(:to_cuiaba) do
      create(:atua_transport_document, tenant:, number: '77002', taker_code: 601, taker_name: 'MOINHO REGIO ALIMENTOS S/A',
                                       issued_at: Time.zone.local(2026, 10, 4, 8))
    end

    before do
      FreightExpenses::CalculateTarpLiningCommand.call(tenant)
      login_as(admin, scope: :user)
    end

    scenario 'lists the tarp lining of each transport document of the group' do
      visit freight_expenses_path
      select 'MOINHO REGIO', from: 'Grupo de clientes'
      click_on 'Aplicar Filtros'

      expect(tenant.freight_expenses.tarp_lining.count).to eq(2)
      expect(html_table_to_rows).to eq(
        [
          ['CT-e', 'Emitido em', 'Tomador', 'Tipo', 'Regra ou custo', 'Base de cálculo', 'Taxa', 'Valor', 'Ações'],
          ['77001', '05/10/2026 08:00', 'MOINHO REGIO ALIMENTOS S/A', 'Forro de lona', 'Moinho Regio — valor fixo por CT-e', '-',
           'R$ 55,00 por CT-e', 'R$ 55,00', ''],
          ['77002', '04/10/2026 08:00', 'MOINHO REGIO ALIMENTOS S/A', 'Forro de lona', 'Moinho Regio — valor fixo por CT-e', '-',
           'R$ 55,00 por CT-e', 'R$ 55,00', ''],
        ],
      )
      expect(dl_to_hash('#freight_expenses_totals')).to eq('Total das despesas' => 'R$ 110,00')
    end
  end

  context 'when an admin is signed in and the fuel was calculated' do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:truck_groups_resource) { create(:resource, name: 'Grupos de caminhões', slug: 'truck_groups') }
    let!(:rodotrem) { create(:truck_group, tenant:, name: 'Rodotrem', axles: [9], fuel_percentage: BigDecimal('32.5')) }
    let!(:steel) do
      create(:atua_transport_document, tenant:, number: '78001', axles: 9, freight_cents: 1_000_000, taker_name: 'USIMINAS',
                                       issued_at: Time.zone.local(2026, 10, 5, 8))
    end

    before do
      create(:atua_transport_document, tenant:, number: '78002', axles: 6, freight_cents: 1_000_000)
      FreightExpenses::CalculateFuelCommand.call(tenant)
      login_as(admin, scope: :user)
    end

    scenario 'lists the fuel of each transport document of an active truck group' do
      visit freight_expenses_path
      select 'Combustível', from: 'Tipo'
      click_on 'Aplicar Filtros'

      expect(tenant.freight_expenses.fuel.count).to eq(1)
      expect(html_table_to_rows).to eq(
        [
          ['CT-e', 'Emitido em', 'Tomador', 'Tipo', 'Regra ou custo', 'Base de cálculo', 'Taxa', 'Valor', 'Ações'],
          ['78001', '05/10/2026 08:00', 'USIMINAS', 'Combustível', 'Rodotrem', 'R$ 10.000,00', '32,5%', 'R$ 3.250,00', ''],
        ],
      )
      expect(dl_to_hash('#freight_expenses_totals')).to eq('Total das despesas' => 'R$ 3.250,00')

      click_on 'Rodotrem'

      expect(page).to have_current_path(truck_group_path(rodotrem))
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }

    before { login_as(operator, scope: :user) }

    context 'without access to the freight expenses' do
      scenario 'is sent back with an access denied message' do
        visit freight_expenses_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the freight expenses only' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'does not offer the recalculation' do
        visit freight_expenses_path

        expect(page).to have_css('h1.page-title', text: 'Despesas de frete')
        expect(page).to have_no_button('Recalcular despesas')
      end

      scenario 'cannot recalculate through a forged request' do
        expect { page.driver.submit :post, recalculate_freight_expenses_path, {} }
          .not_to have_enqueued_job(FreightExpenses::CalculateJob)

        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:to_minas) do
      create(:atua_transport_document, tenant:, number: '74001', taker_code: 501, destination_state: 'MG', freight_cents: 1_000_000)
    end

    before do
      FreightExpenses::CalculateCommissionsCommand.call(tenant)
      login_as(admin, scope: :user)
    end

    scenario 'keeps the transport document and the amount without scrolling sideways' do
      visit freight_expenses_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'CT-E')
      expect(page).to have_css('th', text: 'VALOR')
      expect(page).to have_no_css('th', text: 'TOMADOR')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
