require 'rails_helper'

describe 'Manifests' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Manifestos', slug: 'manifests', writable: false) }

  context 'without a signed in user' do
    let!(:manifest) { create(:atua_manifest, tenant:) }

    scenario 'redirects the listing to the login screen' do
      visit manifests_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'redirects the details to the login screen' do
      visit manifest_path(manifest)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when there are no manifests' do
      scenario 'shows the empty state message' do
        visit manifests_path

        expect(Atua::Manifest.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are manifests' do
      let!(:closed) do
        create(:atua_manifest, tenant:, number: '40772', branch_name: 'JR TRANSPORTES', issued_on: Date.new(2026, 10, 1),
                               departure_on: Date.new(2026, 10, 2), plate: 'RHJ4E07', status: 'Encerrado', goods_value_cents: 11_259_672)
      end
      let!(:canceled) do
        create(:atua_manifest, tenant:, number: '40780', branch_name: 'TRANSJR SABARA', issued_on: Date.new(2026, 10, 6),
                               departure_on: nil, plate: 'EXU0F72', status: 'Cancelado', goods_value_cents: nil)
      end
      let!(:removed) { create(:atua_manifest, tenant:, number: '40790', removed_from_atua_at: Time.current) }
      let!(:stranger) { create(:atua_manifest, tenant: other_tenant, number: '40791') }

      scenario 'lists the active manifests of the tenant from the tax menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Fiscal'
          click_on 'Manifestos'
        end

        expect(page).to have_current_path(manifests_path)
        expect(Atua::Manifest.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            ['Número', 'Emitido em', 'Saída', 'Placa', 'Cliente', 'Motorista', 'Frete bruto', 'Situação', 'Ações'],
            ['40780 TRANSJR SABARA', '06/10/2026', '-', 'EXU0F72', '-', '-', 'R$ 0,00', 'Cancelado', ''],
            ['40772 JR TRANSPORTES', '01/10/2026', '02/10/2026', 'RHJ4E07', '-', '-', 'R$ 0,00', 'Válido', ''],
          ],
        )
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Total 2', 'Válidos 1', 'Cancelados 1'])
        expect(page).to have_text('2 registros')
        expect(page).to have_link(href: manifest_path(closed), title: 'Visualizar')
        expect(page).to have_no_text('40790')
        expect(page).to have_no_text('40791')
      end

      scenario 'filters the manifests by number' do
        visit manifests_path
        fill_in 'Número do manifesto', with: '40772'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Número', 'Emitido em', 'Saída', 'Placa', 'Cliente', 'Motorista', 'Frete bruto', 'Situação', 'Ações'],
            ['40772 JR TRANSPORTES', '01/10/2026', '02/10/2026', 'RHJ4E07', '-', '-', 'R$ 0,00', 'Válido', ''],
          ],
        )
      end

      scenario 'filters the manifests by plate, period and situation' do
        visit manifests_path
        fill_in 'Placa', with: 'exu 0f72'
        fill_in 'Emitidos a partir de', with: '2026-10-02'
        fill_in 'Emitidos até', with: '2026-10-31'
        select 'Cancelado', from: 'Situação'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Número', 'Emitido em', 'Saída', 'Placa', 'Cliente', 'Motorista', 'Frete bruto', 'Situação', 'Ações'],
            ['40780 TRANSJR SABARA', '06/10/2026', '-', 'EXU0F72', '-', '-', 'R$ 0,00', 'Cancelado', ''],
          ],
        )
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Total 1', 'Válidos 0', 'Cancelados 1'])
      end

      scenario 'does not show a manifest removed from Atua' do
        visit manifest_path(removed)

        expect(page.status_code).to eq(404)
      end

      scenario 'does not show a manifest of another tenant' do
        visit manifest_path(stranger)

        expect(page.status_code).to eq(404)
      end

      scenario 'has no route to create a manifest' do
        expect { page.driver.submit :post, manifests_path, {} }.not_to change(Atua::Manifest, :count)

        expect(page.status_code).to eq(404)
      end

      scenario 'has no route to remove a manifest' do
        expect { page.driver.submit :delete, manifest_path(closed), {} }.not_to change(Atua::Manifest, :count)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when a manifest has every detail and transport documents' do
      let!(:transport_documents_resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }
      let!(:manifest) do
        create(:atua_manifest, tenant:, code: 41_236, number: '40772', series: 1, model: 58, access_key: '31261000000000000000580010000407721000000000',
                               status: 'Encerrado', branch_name: 'JR TRANSPORTES', company_city: 'Ipatinga', company_state: 'MG',
                               issued_on: Date.new(2026, 10, 1), departure_on: Date.new(2026, 10, 2),
                               trip_started_at: Time.zone.local(2026, 10, 2, 6, 30), closed_at: Time.zone.local(2026, 10, 3, 18),
                               plate: 'RHJ4E07', goods_value_cents: 11_259_672, notes: 'Entrega agendada')
      end
      let!(:transport_document) do
        create(:atua_transport_document, tenant:, number: '74130', series: 1, branch_name: 'JR TRANSPORTES', toll_cents: 20_000)
      end
      let!(:linked_document) do
        create(:atua_manifest_document, tenant:, manifest_code: 41_236, transport_document_number: '74130', transport_document_series: 1,
                                        branch_name: 'JR TRANSPORTES', recipient_name: 'FIAT', origin_city: 'Ipatinga', origin_state: 'MG',
                                        destination_city: 'Betim', destination_state: 'MG', weight_kg: BigDecimal('19170'), freight_cents: 555_040)
      end
      let!(:unlinked_document) do
        create(:atua_manifest_document, tenant:, manifest_code: 41_236, transport_document_number: '74199', transport_document_series: 1,
                                        branch_name: 'JR TRANSPORTES', recipient_name: nil, weight_kg: nil, freight_cents: nil)
      end

      scenario 'shows every detail of the manifest and its transport documents' do
        visit manifests_path
        click_on '40772'

        expect(page).to have_current_path(manifest_path(manifest))
        expect(page).to have_css('h1.page-title', text: 'Manifesto 40772')
        expect(dl_to_hash('#manifest_data')).to eq(
          'Número' => '40772',
          'Série' => '1',
          'Modelo' => '58',
          'Chave de acesso' => manifest.access_key,
          'Situação' => 'Válido',
          'Situação na Atua' => 'Encerrado',
          'Filial' => 'JR TRANSPORTES',
          'Cidade da filial' => 'Ipatinga/MG',
          'Emitido em' => '01/10/2026',
          'Saída' => '02/10/2026',
          'Início da viagem' => '02/10/2026 06:30',
          'Encerrado em' => '03/10/2026 18:00',
          'Placa' => 'RHJ4E07',
          'Valor da mercadoria' => 'R$ 112.596,72',
          'Observações' => 'Entrega agendada',
        )
        expect(manifest.documents.count).to eq(2)
        expect(html_table_to_rows(table: find_by_id('manifest_documents'))).to eq(
          [
            ['CT-e', 'Destinatário', 'Origem / Destino', 'Peso (kg)', 'Frete', 'Pedágio'],
            ['74130', 'FIAT', 'Ipatinga/MG → Betim/MG', '19.170,00', 'R$ 5.550,40', 'R$ 200,00 Fora do frete'],
            ['74199', '-', '- → -', '-', '-', '-'],
          ],
        )
        expect(page).to have_no_link('74199')
      end

      scenario 'opens a transport document of the manifest' do
        visit manifest_path(manifest)
        click_on '74130'

        expect(page).to have_current_path(transport_document_path(transport_document))
      end

      context 'with access to the freight expenses' do
        let!(:freight_expenses_resource) { create(:resource, name: 'Despesas de frete', slug: 'freight_expenses', writable: false) }
        let!(:other_transport_document) do
          create(:atua_transport_document, tenant:, number: '74131', series: 1, branch_name: 'JR TRANSPORTES', freight_cents: 300_000,
                                           weight_freight_cents: 260_000, toll_cents: 15_000, icms_cents: 25_000)
        end

        before do
          create(:atua_manifest_document, tenant:, manifest_code: 41_236, transport_document_number: '74131', transport_document_series: 1,
                                          branch_name: 'JR TRANSPORTES')
          create(:freight_expense, tenant:, transport_document:, amount_cents: 11_101)
          create(:freight_expense, :insurance, tenant:, transport_document:)
          create(:freight_expense, tenant:, transport_document: other_transport_document, amount_cents: 6_000)
          create(:freight_expense, :tonnage, tenant:, transport_document: other_transport_document)
          create(:atua_expense, tenant:, history_name: 'DESCARGA - CHAPA', total_cents: 35_000, cost_object: other_transport_document)
          outside = create(:atua_transport_document, tenant:, number: '74200', series: 1, branch_name: 'JR TRANSPORTES')
          create(:freight_expense, tenant:, transport_document: outside, amount_cents: 99_999)
        end

        scenario 'shows the net freight of the trip discounting only the toll inside the gross freight' do
          visit manifest_path(manifest)

          expect(FreightExpense.count).to eq(5)
          expect(dl_to_hash('#manifest_net_freight')).to eq(
            'Frete bruto' => 'R$ 3.555,04',
            '(−) Comissões' => 'R$ 171,01',
            '(−) Custos por tonelada' => 'R$ 408,53',
            '(−) Seguro da carga' => 'R$ 2,20',
            '(−) Forro de lona' => 'R$ 0,00',
            '(−) Combustível' => 'R$ 0,00',
            '(−) Despesas do frete na Atua' => 'R$ 350,00',
            '(−) Pedágio incluso no frete' => 'R$ 150,00',
            '(=) Frete líquido' => 'R$ 2.473,30',
            'Pedágio fora do frete (não descontado)' => 'R$ 200,00',
          )
        end

        scenario 'lists the commissions, the tonnage costs and the cargo insurance of the transport documents of the trip with the total' do
          visit manifest_path(manifest)

          expect(FreightExpense.count).to eq(5)
          expect(html_table_to_rows(table: find_by_id('manifest_freight_expenses'))).to eq(
            [
              ['CT-e', 'Tipo', 'Regra ou custo', 'Base de cálculo', 'Taxa', 'Valor'],
              ['74130', 'Comissão', 'Nacional', 'R$ 1.000,00', '2,00%', 'R$ 111,01'],
              ['74130', 'Seguro da carga', 'Alíquota de seguro', 'R$ 10.000,00', '0,022%', 'R$ 2,20'],
              ['74131', 'Comissão', 'Nacional', 'R$ 1.000,00', '2,00%', 'R$ 60,00'],
              ['74131', 'Custo por tonelada', 'Brasiltec – Cubatão/SP (Cubatão)', '32,500 t', 'R$ 12,57/t', 'R$ 408,53'],
            ],
          )
          expect(page).to have_css('#manifest_freight_expenses_total', text: 'Total das despesas do frete R$ 581,74')
        end
      end

      context 'without access to the freight expenses' do
        let!(:freight_expense) { create(:freight_expense, tenant:, transport_document:, amount_cents: 11_101) }

        scenario 'does not show the freight expenses' do
          visit manifest_path(manifest)

          expect(FreightExpense.count).to eq(1)
          expect(page).to have_css('h1.page-title', text: 'Manifesto 40772')
          expect(page).to have_no_css('#manifest_net_freight')
          expect(page).to have_no_css('#manifest_freight_expenses')
        end
      end

      context 'with access to the expenses' do
        let!(:expenses_resource) { create(:resource, name: 'Despesas', slug: 'expenses', writable: false) }

        scenario 'tells that there are no expenses linked to the transport documents of the manifest' do
          visit manifest_path(manifest)

          expect(Atua::Expense.count).to eq(0)
          expect(page).to have_text('Nenhuma despesa vinculada aos CT-es deste manifesto.')
        end

        context 'when the transport documents of the manifest have expenses' do
          let!(:other_transport_document) do
            create(:atua_transport_document, tenant:, number: '74131', series: 1, branch_name: 'JR TRANSPORTES')
          end
          let!(:toll) do
            create(:atua_expense, tenant:, code: 590_401, posted_at: Time.zone.local(2026, 10, 2, 7), posted_on: Date.new(2026, 10, 2),
                                  history_name: 'PEDAGIO', payee_name: 'VIA 040', total_cents: 15_000, cost_object: transport_document)
          end
          let!(:unload) do
            create(:atua_expense, tenant:, code: 590_402, posted_at: Time.zone.local(2026, 10, 3, 15), posted_on: Date.new(2026, 10, 3),
                                  history_name: 'DESCARGA - CHAPA', payee_name: nil, total_cents: 35_000, cost_object: other_transport_document)
          end

          before do
            create(:atua_manifest_document, tenant:, manifest_code: 41_236, transport_document_number: '74131', transport_document_series: 1,
                                            branch_name: 'JR TRANSPORTES')
            outside = create(:atua_transport_document, tenant:, number: '74200', series: 1, branch_name: 'JR TRANSPORTES')
            create(:atua_expense, tenant:, history_name: 'FORA DA VIAGEM', cost_object: outside)
            create(:atua_expense, tenant:, history_name: 'PNEUS', cost_object: create(:atua_vehicle, tenant:, plate: 'RHJ4E07'))
            create(:atua_expense, tenant:, history_name: 'REMOVIDA', cost_object: transport_document, removed_from_atua_at: Time.current)
          end

          scenario 'lists the expenses of the transport documents of the trip with the total' do
            visit manifest_path(manifest)

            expect(Atua::Expense.count).to eq(5)
            expect(html_table_to_rows(table: find_by_id('manifest_expenses'))).to eq(
              [
                ['Histórico', 'CT-e', 'Lançado em', 'Favorecido', 'Valor total'],
                ['DESCARGA - CHAPA', '74131', '03/10/2026', '-', 'R$ 350,00'],
                ['PEDAGIO', '74130', '02/10/2026', 'VIA 040', 'R$ 150,00'],
              ],
            )
            expect(page).to have_css('#manifest_expenses_total', text: 'Total de despesas R$ 500,00')
          end

          scenario 'opens an expense of the trip' do
            visit manifest_path(manifest)
            click_on 'PEDAGIO'

            expect(page).to have_current_path(expense_path(toll))
          end

          scenario 'opens the transport document of an expense' do
            visit manifest_path(manifest)
            within('#manifest_expenses') { click_on '74131' }

            expect(page).to have_current_path(transport_document_path(other_transport_document))
          end
        end
      end
    end

    context 'when the manifest has an empty leg from the previous trip of the truck' do
      let!(:previous_manifest) { create(:atua_manifest, tenant:, code: 41_100, number: '40700', plate: 'RHJ4E07') }
      let!(:manifest) { create(:atua_manifest, tenant:, code: 41_200, number: '40772', plate: 'RHJ4E07') }
      let!(:origin) do
        create(:location, lookup_key: 'RUA DAS FLORES 10|BETIM|MG', street: 'RUA DAS FLORES 10', city: 'BETIM', state: 'MG', precision_type: 'address')
      end
      let!(:destination) { create(:location, lookup_key: '|CONTAGEM|MG', city: 'CONTAGEM', state: 'MG', precision_type: 'city') }
      let!(:empty_leg) do
        create(:empty_leg, tenant:, plate: 'RHJ4E07', previous_manifest_code: 41_100, next_manifest_code: 41_200, origin:, destination:,
                           distance_km: BigDecimal('23.45'), precision_type: 'city', calculated_at: Time.zone.local(2026, 10, 3, 9, 15))
      end

      scenario 'shows the empty kilometers and opens the previous trip' do
        visit manifest_path(manifest)

        expect(EmptyLeg.count).to eq(1)
        expect(dl_to_hash('#manifest_empty_leg')).to eq(
          'Viagem anterior' => '40700',
          'Última entrega da viagem anterior' => 'RUA DAS FLORES 10 - BETIM/MG',
          'Primeira coleta desta viagem' => 'CONTAGEM/MG',
          'KM vazio' => '23,45 km',
          'Precisão' => 'Centro da cidade',
          'Calculado em' => '03/10/2026 09:15',
        )

        click_on '40700'

        expect(page).to have_current_path(manifest_path(previous_manifest))
        expect(page).to have_text('Sem KM vazio, porque não há viagem anterior desta placa.')
      end

      context 'when the first pickup could not be located' do
        before { empty_leg.update!(status_type: 'unlocated', distance_km: nil, precision_type: nil, destination: nil) }

        scenario 'shows the status instead of the distance' do
          visit manifest_path(manifest)

          expect(dl_to_hash('#manifest_empty_leg')).to eq(
            'Viagem anterior' => '40700',
            'Última entrega da viagem anterior' => 'RUA DAS FLORES 10 - BETIM/MG',
            'Primeira coleta desta viagem' => '-',
            'KM vazio' => 'Endereço não localizado',
            'Precisão' => '-',
            'Calculado em' => '03/10/2026 09:15',
          )
        end
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:manifest) { create(:atua_manifest, tenant:, number: '40772') }

    before { login_as(operator, scope: :user) }

    context 'without access to the manifests' do
      scenario 'is sent back with an access denied message' do
        visit manifests_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end

      scenario 'cannot open a manifest' do
        visit manifest_path(manifest)

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the manifests' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'lists and opens the manifests' do
        visit manifests_path

        expect(Atua::Manifest.count).to eq(1)
        expect(html_table_to_rows.size).to eq(2)

        click_on '40772'

        expect(page).to have_current_path(manifest_path(manifest))
      end

      context 'when the manifest has a transport document' do
        let!(:transport_document) { create(:atua_transport_document, tenant:, number: '74130', series: 1, branch_name: manifest.branch_name) }
        let!(:document) do
          create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: transport_document.number,
                                          transport_document_series: 1, branch_name: manifest.branch_name)
        end

        scenario 'does not link the transport documents without access to them' do
          visit manifest_path(manifest)

          expect(page).to have_css('#manifest_documents', text: document.transport_document_number)
          expect(page).to have_no_link('74130')
        end

        scenario 'does not show the expenses of the trip without access to them' do
          create(:atua_expense, tenant:, history_name: 'PEDAGIO', cost_object: transport_document)

          visit manifest_path(manifest)

          expect(Atua::Expense.count).to eq(1)
          expect(page).to have_no_text('Despesas da viagem')
          expect(page).to have_no_text('PEDAGIO')
        end
      end
    end
  end

  context 'on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:manifest) { create(:atua_manifest, tenant:, number: '40772') }

    before do
      login_as(admin, scope: :user)
      use_mobile_screen
    end

    context 'when the manifest has expenses' do
      let!(:expenses_resource) { create(:resource, name: 'Despesas', slug: 'expenses', writable: false) }

      before do
        transport_document = create(:atua_transport_document, tenant:, number: '74130', series: 1, branch_name: manifest.branch_name)
        create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: '74130',
                                        transport_document_series: 1, branch_name: manifest.branch_name)
        create(:atua_expense, tenant:, history_name: 'PEDAGIO', payee_name: 'VIA 040', total_cents: 15_000, cost_object: transport_document)
      end

      scenario 'keeps only the history and the total of the expenses without horizontal scroll' do
        visit manifest_path(manifest)

        expect(page).to have_css('#manifest_expenses td', text: 'R$ 150,00')
        expect(page).to have_no_css('#manifest_expenses th', text: 'Favorecido')
        expect(page).to have_no_css('#manifest_expenses th', text: 'CT-e')
        expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      end
    end

    context 'when the manifest has a transport document with toll' do
      let!(:transport_documents_resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }

      before do
        create(:atua_transport_document, tenant:, number: '74130', series: 1, branch_name: manifest.branch_name, freight_cents: 100_000,
                                         weight_freight_cents: 90_000, toll_cents: 10_000)
        create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: '74130',
                                        transport_document_series: 1, branch_name: manifest.branch_name, freight_cents: 100_000)
      end

      scenario 'hides the toll column of the transport documents without horizontal scroll' do
        visit manifest_path(manifest)

        expect(page).to have_css('#manifest_documents td', text: 'R$ 1.000,00')
        expect(page).to have_no_css('#manifest_documents th', text: 'Pedágio')
        expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      end
    end

    scenario 'keeps only the essential columns without horizontal scroll' do
      visit manifests_path

      expect(page).to have_link('40772')
      expect(page).to have_no_css('th', text: 'Placa')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end

  context 'on a tablet', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }

    before do
      login_as(admin, scope: :user)
      use_mobile_screen(width: 820, height: 1180)
    end

    scenario 'stacks the period filters one below the other' do
      visit manifests_path
      find(:link, href: '#filtersModal').click

      within('#filtersModal') { expect(page).to have_field('Emitidos até') }
      start_top = page.evaluate_script("document.getElementById('start_date').getBoundingClientRect().top")
      end_top = page.evaluate_script("document.getElementById('end_date').getBoundingClientRect().top")
      expect(end_top).to be > start_top
    end
  end
end
