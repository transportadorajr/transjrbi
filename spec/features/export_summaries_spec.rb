require 'rails_helper'

describe 'Export summary', flipper: { export_summary: :tenant } do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Resumo da exportação', slug: 'export_summary', writable: false) }
  let!(:arcelor) { create(:customer_group, tenant:, name: 'ARCELORMITTAL') }
  let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
  let!(:sul_fluminense) { create(:export_plant, tenant:, customer_group: arcelor, name: 'Sul Fluminense', cities: ['RESENDE', 'BARRA MANSA']) }

  before do
    travel_to Time.zone.local(2026, 11, 18, 10)
    create(:atua_customer, tenant:, code: 100, name: 'ARCELORMITTAL BRASIL S.A.', customer_group: arcelor)
    create(:atua_customer, tenant:, code: 200, name: 'USINAS SIDERURGICAS DE MINAS GERAIS', customer_group: usiminas)
    create(:atua_customer, tenant:, code: 300, name: 'ACEROS ASUNCION SA', city: 'ASUNCION', state: 'EX', country_type: 'paraguay')
    create(:atua_customer, tenant:, code: 301, name: 'ACINDAR', city: 'BUENOS AIRES', state: 'EX', country_type: 'argentina')
    create(:atua_customer, tenant:, code: 302, name: 'FERROSIDER S/A', city: 'EXTERIOR', state: 'EX')
  end

  def create_loading(code:, on:, documents:, target: tenant)
    create(:atua_manifest, tenant: target, code:, number: code.to_s, plate: 'RHJ4E07', trip_started_at: on.in_time_zone.change(hour: 8))
    documents.each do |number, attributes|
      create(:atua_transport_document, tenant: target, number:, cargo_destination_type: 'export', taker_code: 100, recipient_code: 300,
                                       recipient_name: 'ACEROS ASUNCION SA', origin_city: 'JUIZ DE FORA', origin_state: 'MG', **attributes)
      create(:atua_manifest_document, tenant: target, manifest_code: code, transport_document_number: number)
    end
  end

  context 'without a signed in user' do
    scenario 'redirects to the login screen' do
      visit export_summary_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'without export loadings in the period' do
      scenario 'shows the empty state with zeroed totals' do
        visit export_summary_path

        expect(Atua::TransportDocument.count).to eq(0)
        expect(page).to have_css('.counter-card', text: "Toneladas carregadas\n0,0 t")
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'with export loadings' do
      before do
        create_loading(code: 1, on: Date.new(2026, 11, 2), documents: [
                         ['74001', { weight_tons: BigDecimal('30') }],
                         ['74002', { weight_tons: BigDecimal('27.5') }],
                         ['74003', { document_kind: 'ce', weight_tons: BigDecimal('57.5') }],
                         ['74004', { weight_tons: BigDecimal('30'), canceled_at: Time.zone.local(2026, 11, 2, 9) }],
                       ])
        create_loading(code: 2, on: Date.new(2026, 11, 16), documents: [
                         ['74005', { weight_tons: 32, recipient_code: 301, recipient_name: 'ACINDAR', origin_city: 'RESENDE', origin_state: 'RJ' }],
                       ])
        create_loading(code: 3, on: Date.new(2026, 11, 17), documents: [
                         ['74006', { weight_tons: 30, recipient_code: 301, recipient_name: 'ACINDAR', origin_city: 'BARRA MANSA', origin_state: 'RJ' }],
                       ])
        create_loading(code: 4, on: Date.new(2026, 11, 10), documents: [
                         ['74007', { weight_tons: 25, taker_code: 200, recipient_code: 302, recipient_name: 'FERROSIDER S/A', origin_city: 'IPATINGA' }],
                       ])
        create_loading(code: 5, on: Date.new(2026, 10, 6), documents: [['74008', { weight_tons: 40 }]])
        create_loading(code: 6, on: Date.new(2026, 11, 2), target: other_tenant, documents: [['74009', { weight_tons: 99 }]])
      end

      scenario 'shows the tons of the month by plant and country from the intelligence menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Inteligência'
          click_on 'Resumo da exportação'
        end

        expect(page).to have_current_path(export_summary_path)
        expect(page).to have_css('h1.page-title', text: 'Resumo da Exportação')
        expect(page).to have_text('Carregamentos de 01/11/2026 a 30/11/2026')
        expect(page).to have_css('.counter-card', text: "Toneladas carregadas\n144,5 t")
        expect(page).to have_css('.counter-card', text: "Carregamentos\n4")
        expect(page).to have_css('.counter-card', text: "CT-es\n5")
        expect(html_table_to_rows).to eq(
          [
            ['Planta de origem', 'País de destino', 'Toneladas', 'Carregamentos', 'CT-es', '% do total', 'Ações'],
            ['Sul Fluminense ARCELORMITTAL · Argentina', 'Argentina', '62,0 t', '2', '2', '42,9%', ''],
            ['JUIZ DE FORA/MG ARCELORMITTAL · Paraguai', 'Paraguai', '57,5 t', '1', '2', '39,8%', ''],
            ['IPATINGA/MG USIMINAS · País não identificado', 'País não identificado', '25,0 t', '1', '1', '17,3%', ''],
            ['Total', '', '144,5 t', '4', '5', '100,0%', ''],
          ],
        )
        expect(page).to have_no_text('99,0 t')
      end

      scenario 'compares the week and the month to date with the same days of the previous ones' do
        visit export_summary_path

        within('#export_summary_comparisons') do
          expect(page).to have_text("Semana atual (15/11 a 18/11)\n62,0 t\n2 carregamentos")
          expect(page).to have_text('+148,0% em relação aos mesmos dias do período anterior (08/11 a 11/11: 25,0 t)')
          expect(page).to have_text("Mês atual (01/11 a 18/11)\n144,5 t\n4 carregamentos")
          expect(page).to have_text('+261,3% em relação aos mesmos dias do período anterior (01/10 a 18/10: 40,0 t)')
        end
      end

      scenario 'filters by customer group, plant and country' do
        visit export_summary_path(customer_group_id: arcelor.id, country: 'argentina')

        expect(page).to have_link('Limpar Filtros')
        expect(html_table_to_rows[1..]).to eq(
          [['Sul Fluminense ARCELORMITTAL · Argentina', 'Argentina', '62,0 t', '2', '2', '100,0%', ''],
           ['Total', '', '62,0 t', '2', '2', '100,0%', '']],
        )

        visit export_summary_path(plant: 'city-IPATINGA-MG')

        expect(html_table_to_rows[1].first).to eq('IPATINGA/MG USIMINAS · País não identificado')
      end

      scenario 'changes the period with the presets' do
        visit export_summary_path
        click_on 'Mês passado'

        expect(page).to have_current_path(export_summary_path(start_date: '2026-10-01', end_date: '2026-10-31'))
        expect(page).to have_css('.counter-card', text: "Toneladas carregadas\n40,0 t")
      end

      scenario 'opens the documents of a total for checking' do
        create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false)

        visit export_summary_path
        within(:xpath, "//tr[td[contains(., 'JUIZ DE FORA/MG')]]") { click_on 'Ver CT-es' }

        expect(page).to have_css('.modal-title', text: 'ARCELORMITTAL · JUIZ DE FORA/MG · Paraguai')
        expect(page).to have_text('57,5 t em 1 carregamento(s) e 2 CT-es.')
        expect(html_table_to_rows(table: find_by_id('export_summary_documents'))).to eq(
          [
            ['CT-e', 'Carregamento', 'MDF-e', 'Placa', 'Destinatário', 'Toneladas'],
            ['74001', '02/11/2026', '1', 'RHJ4E07', 'ACEROS ASUNCION SA', '30,0 t'],
            ['74002', '02/11/2026', '1', 'RHJ4E07', 'ACEROS ASUNCION SA', '27,5 t'],
          ],
        )

        click_on '74001'

        expect(page).to have_current_path(transport_document_path(Atua::TransportDocument.find_by!(tenant:, number: '74001')))
      end

      scenario 'opens the documents through a turbo stream' do
        page.driver.header('Accept', 'text/vnd.turbo-stream.html')
        visit documents_export_summary_path(key: 'total')

        expect(page.status_code).to eq(200)
        expect(page.html).to include('turbo-stream action="update" target="remote-container"')
        expect(page.html).to include('74007')
      end

      scenario 'goes back to the summary when the row is no longer there' do
        visit documents_export_summary_path(key: 'unknown')

        expect(page).to have_current_path(export_summary_path)
        expect(page).to have_text('Esta linha não está mais disponível. Confira os dados atualizados.')
      end

      scenario 'exports the summary to PDF' do
        visit export_summary_path(format: :pdf)

        text = PDF::Inspector::Text.analyze(page.body).strings.join(' ')
        expect(page.response_headers['Content-Type']).to include('application/pdf')
        expect(text).to include('Relatório do Resumo da Exportação')
        expect(text).to include('Sul Fluminense')
        expect(text).to include('144,5 t')
      end

      scenario 'refuses an end date before the start date' do
        visit export_summary_path(start_date: '2026-11-10', end_date: '2026-11-01')

        expect(page).to have_current_path(export_summary_path)
        expect(page).to have_text('Carregamentos até não pode ser anterior à data inicial')
      end
    end
  end

  context 'when the export summary is off for the tenant' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before do
      Flipper.disable(:export_summary)
      login_as(owner, scope: :user)
    end

    scenario 'answers not found' do
      visit export_summary_path

      expect(page.status_code).to eq(404)
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }

    before { login_as(operator, scope: :user) }

    scenario 'without access is sent back with an access denied message' do
      visit export_summary_path

      expect(page).to have_current_path(root_path)
      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end

    context 'with read access' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'opens the summary' do
        visit export_summary_path

        expect(page).to have_css('h1.page-title', text: 'Resumo da Exportação')
      end
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before do
      create_loading(code: 1, on: Date.new(2026, 11, 2), documents: [['74001', { weight_tons: 30 }]])
      login_as(owner, scope: :user)
    end

    scenario 'keeps the plant, the tons and the actions and does not scroll sideways' do
      visit export_summary_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'PLANTA DE ORIGEM')
      expect(page).to have_css('th', text: 'TONELADAS')
      expect(page).to have_no_css('th', text: 'PAÍS DE DESTINO')
      expect(page).to have_css('td', text: 'ARCELORMITTAL · Paraguai')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)

      within(:xpath, "//tr[td[contains(., 'JUIZ DE FORA/MG')]]") { click_on 'Ver CT-es' }

      expect(page).to have_css('#export_summary_documents', text: '74001')
    end
  end
end
