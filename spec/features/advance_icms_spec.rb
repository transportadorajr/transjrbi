require 'rails_helper'

describe 'Advance ICMS' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'ICMS antecipado', slug: 'advance_icms', writable: false) }
  let!(:transport_documents_resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }
  let!(:gerdau) { create(:customer_group, tenant:, name: 'GERDAU', terms: ['GERDAU'], pays_advance_icms_at: Time.zone.local(2026, 11, 1)) }
  let!(:arcelor) { create(:customer_group, tenant:, name: 'ARCELOR', terms: ['ARCELOR']) }
  let!(:gerdau_customer) { create(:atua_customer, tenant:, code: 601, name: 'GERDAU ACOS LONGOS S.A', customer_group: gerdau) }
  let!(:arcelor_customer) { create(:atua_customer, tenant:, code: 602, name: 'ARCELORMITTAL BRASIL S.A', customer_group: arcelor) }

  def documents_rows
    html_table_to_rows(table: find_by_id('advance_icms_documents'))
  end

  def create_guide(transport_document, total_cents)
    create(:atua_expense, tenant:, history_code: 503, history_name: 'ICMS ANTECIPADO', payee_name: 'SECRETARIA DE ESTADO DE SAO PAULO',
                          cost_object: transport_document, amount_cents: total_cents, total_cents:)
  end

  context 'without a signed in user' do
    scenario 'redirects the listing to the login screen' do
      visit advance_icms_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are no CT-es started outside the carrier state' do
      let!(:local) do
        create(:atua_transport_document, tenant:, number: '75001', cfop: 6353, origin_state: 'PR', icms_cents: 12_000)
      end

      scenario 'shows the empty state message' do
        visit advance_icms_path

        expect(Atua::TransportDocument.count).to eq(1)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
        expect(page).to have_css('.counter-card', text: "CT-es\n0")
      end
    end

    context 'when there are CT-es with and without advance ICMS guides' do
      let!(:paid) do
        create(:atua_transport_document, tenant:, number: '75830', cfop: 6932, taker_code: 601, taker_name: 'GERDAU ACOS LONGOS S.A',
                                         origin_city: 'SAO PAULO', origin_state: 'SP', issued_at: Time.zone.local(2026, 11, 24, 8),
                                         posted_on: Date.new(2026, 11, 24), freight_cents: 170_395, icms_cents: 20_447)
      end
      let!(:pending) do
        create(:atua_transport_document, tenant:, number: '75845', cfop: 6932, taker_code: 601, taker_name: 'GERDAU ACOS LONGOS S.A',
                                         origin_city: 'SAO PAULO', origin_state: 'SP', issued_at: Time.zone.local(2026, 11, 25, 13, 15),
                                         posted_on: Date.new(2026, 11, 25), freight_cents: 72_343, icms_cents: 8_681)
      end
      let!(:divergent) do
        create(:atua_transport_document, tenant:, number: '75410', cfop: 6932, taker_code: 602, taker_name: 'ARCELORMITTAL BRASIL S.A',
                                         origin_city: 'RESENDE', origin_state: 'RJ', issued_at: Time.zone.local(2026, 11, 10, 9),
                                         posted_on: Date.new(2026, 11, 10), freight_cents: 300_000, icms_cents: 36_000)
      end
      let!(:local) do
        create(:atua_transport_document, tenant:, number: '75001', cfop: 6353, taker_code: 602, taker_name: 'ARCELORMITTAL BRASIL S.A',
                                         origin_city: 'CURITIBA', origin_state: 'PR', icms_cents: 12_000)
      end
      let!(:stranger) do
        create(:atua_transport_document, tenant: other_tenant, number: '75999', cfop: 6932, origin_state: 'SP', icms_cents: 9_000)
      end

      around { |example| travel_to(Time.zone.local(2026, 11, 26, 9)) { example.run } }

      before do
        create_guide(paid, 20_447)
        create_guide(divergent, 30_000)
      end

      scenario 'shows the guides of each customer group against its gross billing' do
        visit advance_icms_path

        expect(tenant.atua_transport_documents.active.not_canceled.freights.count).to eq(4)
        expect(tenant.atua_transport_documents.advance_icms.count).to eq(3)
        expect(html_table_to_rows(table: find_by_id('advance_icms_groups'))).to eq(
          [
            ['Grupo de clientes', 'CT-es', 'ICMS', 'Guias lançadas', 'ICMS pendente', 'Faturamento bruto', 'Guias / faturamento'],
            ['ARCELOR', '1', 'R$ 360,00', 'R$ 300,00', 'R$ 0,00', 'R$ 3.555,04', '8,44%'],
            ['GERDAU', '2', 'R$ 291,28', 'R$ 204,47', 'R$ 86,81', 'R$ 2.427,38', '8,42%'],
          ],
        )
        expect(page).to have_css('#advance_icms_monthly', text: 'Guias de ICMS por mês')
        expect(page).to have_no_css('#advance_icms_overdue')
      end

      scenario 'warns about the pending guides of CT-es issued more than 5 days ago and lists only them' do
        travel 5.days
        visit advance_icms_path(customer_group_id: gerdau.id)

        within('#advance_icms_overdue') do
          expect(page).to have_text('1 guia de ICMS pendente há mais de 5 dias')
          click_on 'Ver os CT-es com a guia atrasada'
        end

        expect(page).to have_current_path(advance_icms_path(customer_group_id: gerdau.id, overdue: '1'))
        expect(tenant.atua_transport_documents.advance_icms.advance_icms_overdue.count).to eq(1)
        expect(documents_rows.drop(1)).to eq(
          [['75845', '25/11/2026 13:15', 'GERDAU ACOS LONGOS S.A', 'SAO PAULO/SP', 'R$ 86,81', 'R$ 0,00', '-R$ 86,81',
            'Guia pendente há mais de 5 dias', '']],
        )
        expect(page).to have_no_css('#advance_icms_overdue')
      end

      scenario 'lists the CT-es of the tenant from the tax menu with the counters and the totals at the bottom' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Fiscal'
          click_on 'ICMS antecipado'
        end

        expect(page).to have_current_path(advance_icms_path)
        expect(Atua::TransportDocument.count).to eq(5)
        expect(tenant.atua_transport_documents.advance_icms.count).to eq(3)
        expect(page).to have_css('.counter-card', text: "CT-es\n3")
        expect(page).to have_css('.counter-card', text: "Guia paga\n1")
        expect(page).to have_css('.counter-card', text: "Guia divergente\n1")
        expect(page).to have_css('.counter-card', text: "Guia pendente\n1")
        expect(documents_rows).to eq(
          [
            ['Número', 'Emitido em', 'Tomador', 'Origem', 'ICMS', 'Guia de ICMS', 'Diferença', 'Situação da guia', 'Ações'],
            ['75845', '25/11/2026 13:15', 'GERDAU ACOS LONGOS S.A', 'SAO PAULO/SP', 'R$ 86,81', 'R$ 0,00', '-R$ 86,81', 'Guia pendente', ''],
            ['75830', '24/11/2026 08:00', 'GERDAU ACOS LONGOS S.A', 'SAO PAULO/SP', 'R$ 204,47', 'R$ 204,47', 'R$ 0,00', 'Guia paga', ''],
            ['75410', '10/11/2026 09:00', 'ARCELORMITTAL BRASIL S.A', 'RESENDE/RJ', 'R$ 360,00', 'R$ 300,00', '-R$ 60,00',
             'Guia divergente', ''],
          ],
        )
        expect(dl_to_hash('#advance_icms_totals')).to eq(
          'ICMS dos CT-es' => 'R$ 651,28', 'Guias de ICMS lançadas' => 'R$ 504,47', 'Diferença entre guias e ICMS' => '-R$ 146,81',
        )
      end

      context 'when the group no longer has the guides paid by the carrier' do
        before { gerdau.update!(pays_advance_icms: false) }

        scenario 'stops listing the CT-e without a guide as pending' do
          visit advance_icms_path(status: 'not_expected')

          expect(tenant.atua_transport_documents.advance_icms.count).to eq(3)
          expect(documents_rows.drop(1)).to eq(
            [['75845', '25/11/2026 13:15', 'GERDAU ACOS LONGOS S.A', 'SAO PAULO/SP', 'R$ 86,81', 'R$ 0,00', '-R$ 86,81', 'Sem guia esperada', '']],
          )
          expect(page).to have_css('.counter-card', text: "Guia pendente\n0")
        end
      end

      scenario 'opens the CT-e from its number' do
        visit advance_icms_path

        click_on '75830'

        expect(page).to have_current_path(transport_document_path(paid))
      end

      scenario 'filters the CT-es by the status of the guide keeping the totals of the filtered CT-es' do
        visit advance_icms_path

        within('#filtersModal') do
          select 'Guia pendente', from: 'Situação da guia'
          click_on 'Aplicar Filtros'
        end

        expect(page).to have_current_path(advance_icms_path, ignore_query: true)
        expect(documents_rows.drop(1).map(&:first)).to eq(%w[75845])
        expect(page).to have_css('.counter-card', text: "CT-es\n1")
        expect(dl_to_hash('#advance_icms_totals')).to eq(
          'ICMS dos CT-es' => 'R$ 86,81', 'Guias de ICMS lançadas' => 'R$ 0,00', 'Diferença entre guias e ICMS' => '-R$ 86,81',
        )
      end

      scenario 'filters the CT-es by customer group, origin state, number and posting period' do
        visit advance_icms_path(customer_group_id: gerdau.id)
        expect(documents_rows.drop(1).map(&:first)).to eq(%w[75845 75830])

        visit advance_icms_path(origin_state: 'RJ')
        expect(documents_rows.drop(1).map(&:first)).to eq(%w[75410])

        visit advance_icms_path(number: '75830')
        expect(documents_rows.drop(1).map(&:first)).to eq(%w[75830])

        visit advance_icms_path(start_date: '2026-11-24', end_date: '2026-11-24')
        expect(documents_rows.drop(1).map(&:first)).to eq(%w[75830])
      end

      scenario 'sorts the CT-es by the guide keeping the filters' do
        visit advance_icms_path(origin_state: 'SP')

        within('#advance_icms_documents thead') { click_on 'Guia de ICMS' }

        expect(page).to have_current_path(advance_icms_path(origin_state: 'SP', sort: 'advance_icms_guide', direction: 'desc'))
        expect(documents_rows.drop(1).map(&:first)).to eq(%w[75830 75845])
      end

      scenario 'exports the CT-es with the totals to a landscape PDF' do
        visit advance_icms_path(format: :pdf)

        expect(page.status_code).to eq(200)
        expect(page.response_headers['Content-Disposition']).to include('inline')
        text = PDF::Inspector::Text.analyze(page.body).strings.join
        expect(text).to include('Relatório de ICMS antecipado', '75845', '75830', '75410', 'Guia divergente', 'R$ 651,28', 'R$ 504,47')
        expect(text).not_to include('75001', '75999')
      end

      scenario 'exports the CT-es to an Excel spreadsheet', :xlsx_service do
        visit advance_icms_path(format: :xlsx, customer_group_id: gerdau.id)

        expect(page.status_code).to eq(200)
        expect(page.response_headers['Content-Disposition']).to include("filename=\"icms-antecipado-#{Date.current.iso8601}.xlsx\"")
        expect(downloaded_xlsx_rows.first).to eq(
          ['Número', 'Emitido em', 'Tomador', 'Grupo de clientes', 'Cidade de origem', 'UF de origem', 'CFOP', 'ICMS', 'Guia de ICMS',
           'Diferença', 'Situação da guia'],
        )
        expect(downloaded_xlsx_records.map { |record| record.slice('Número', 'Grupo de clientes', 'ICMS', 'Guia de ICMS', 'Situação da guia') })
          .to eq(
            [{ 'Número' => '75845', 'Grupo de clientes' => 'GERDAU', 'ICMS' => 86.81, 'Guia de ICMS' => 0, 'Situação da guia' => 'Guia pendente' },
             { 'Número' => '75830', 'Grupo de clientes' => 'GERDAU', 'ICMS' => 204.47, 'Guia de ICMS' => 204.47,
               'Situação da guia' => 'Guia paga' }],
          )
        expect(downloaded_xlsx_rows(1)).to eq(
          [['Grupo de clientes', 'CT-es', 'ICMS', 'Guias lançadas', 'ICMS pendente', 'Faturamento bruto', 'Guias / faturamento'],
           ['GERDAU', 2, 291.28, 204.47, 86.81, 2427.38, 0.0842]],
        )
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:transport_document) do
      create(:atua_transport_document, tenant:, number: '75830', cfop: 6932, origin_state: 'SP', icms_cents: 20_447)
    end

    before { login_as(operator, scope: :user) }

    context 'without access to the advance ICMS' do
      scenario 'is sent back with an access denied message' do
        visit advance_icms_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the advance ICMS but not to the CT-es' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'lists the CT-es without linking them' do
        visit advance_icms_path

        expect(documents_rows.drop(1).map(&:first)).to eq(%w[75830])
        expect(page).to have_no_link('75830')
      end
    end
  end

  context 'on a phone', :js do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }
    let!(:transport_document) do
      create(:atua_transport_document, tenant:, number: '75830', cfop: 6932, taker_name: 'GERDAU ACOS LONGOS S.A', origin_state: 'SP',
                                       icms_cents: 20_447)
    end

    before do
      login_as(owner, scope: :user)
      use_mobile_screen
    end

    scenario 'keeps only the CT-e and the status of the guide without horizontal scroll' do
      visit advance_icms_path

      expect(page).to have_link('75830')
      expect(page).to have_css('td', text: 'Sem guia esperada')
      expect(page).to have_no_css('th', text: 'Tomador')
      expect(page).to have_no_css('th', text: 'Guia de ICMS')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
