require 'rails_helper'

describe 'Transport documents' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }

  context 'without a signed in user' do
    let!(:transport_document) { create(:atua_transport_document, tenant:) }

    scenario 'redirects the listing to the login screen' do
      visit transport_documents_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'redirects the details to the login screen' do
      visit transport_document_path(transport_document)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when there are no transport documents' do
      scenario 'shows the empty state message' do
        visit transport_documents_path

        expect(Atua::TransportDocument.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are transport documents' do
      let!(:authorized) do
        create(:atua_transport_document, tenant:, number: '74130', sender_name: 'USIMINAS', issued_at: Time.zone.local(2026, 10, 1, 16, 45),
                                         posted_on: Date.new(2026, 10, 1), origin_city: 'Ipatinga', origin_state: 'MG', destination_city: 'Betim', destination_state: 'MG',
                                         plate: 'EXU0F72', freight_cents: 55_504)
      end
      let!(:canceled) do
        create(:atua_transport_document, tenant:, number: '74131', sender_name: 'GERDAU', issued_at: Time.zone.local(2026, 10, 5, 8),
                                         posted_on: Date.new(2026, 10, 5), canceled_at: Time.zone.local(2026, 10, 5, 9), plate: 'RHJ4E07', freight_cents: 120_000)
      end
      let!(:removed) { create(:atua_transport_document, tenant:, number: '74132', removed_from_atua_at: Time.current) }
      let!(:stranger) { create(:atua_transport_document, tenant: other_tenant, number: '74133') }

      scenario 'lists the active transport documents of the tenant from the tax menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Fiscal'
          click_on 'CT-es'
        end

        expect(page).to have_current_path(transport_documents_path)
        expect(Atua::TransportDocument.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            ['Número', 'Lançado em', 'Origem / Destino', 'Placa', 'Frete', 'Situação', 'Ações'],
            ['74131 GERDAU', '05/10/2026', '- → -', 'RHJ4E07', 'R$ 1.200,00', 'Cancelado', ''],
            ['74130 USIMINAS', '01/10/2026', 'Ipatinga/MG → Betim/MG', 'EXU0F72', 'R$ 555,04', 'Válido', ''],
          ],
        )
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Total 2', 'Válidos 1', 'Cancelados 1'])
        expect(page).to have_text('2 registros')
        expect(page).to have_link(href: transport_document_path(authorized), title: 'Visualizar')
        expect(page).to have_no_text('74132')
        expect(page).to have_no_text('74133')
        expect(page).to have_no_link('Novo')
      end

      scenario 'filters the transport documents by number' do
        visit transport_documents_path
        fill_in 'Número do CT-e', with: '74130'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Número', 'Lançado em', 'Origem / Destino', 'Placa', 'Frete', 'Situação', 'Ações'],
            ['74130 USIMINAS', '01/10/2026', 'Ipatinga/MG → Betim/MG', 'EXU0F72', 'R$ 555,04', 'Válido', ''],
          ],
        )
      end

      scenario 'filters the transport documents by plate, period and situation' do
        visit transport_documents_path
        fill_in 'Placa', with: 'rhj-4e07'
        fill_in 'Lançados a partir de', with: '2026-10-02'
        fill_in 'Lançados até', with: '2026-10-31'
        select 'Cancelado', from: 'Situação'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Número', 'Lançado em', 'Origem / Destino', 'Placa', 'Frete', 'Situação', 'Ações'],
            ['74131 GERDAU', '05/10/2026', '- → -', 'RHJ4E07', 'R$ 1.200,00', 'Cancelado', ''],
          ],
        )
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Total 1', 'Válidos 0', 'Cancelados 1'])
      end

      scenario 'does not show a transport document removed from Atua' do
        visit transport_document_path(removed)

        expect(page.status_code).to eq(404)
      end

      scenario 'does not show a transport document of another tenant' do
        visit transport_document_path(stranger)

        expect(page.status_code).to eq(404)
      end

      scenario 'has no route to create a transport document' do
        expect { page.driver.submit :post, transport_documents_path, {} }.not_to change(Atua::TransportDocument, :count)

        expect(page.status_code).to eq(404)
      end

      scenario 'has no route to remove a transport document' do
        expect { page.driver.submit :delete, transport_document_path(authorized), {} }.not_to change(Atua::TransportDocument, :count)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when transport documents have different drivers and customer groups' do
      let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
      let!(:gerdau) { create(:customer_group, tenant:, name: 'GERDAU') }
      let!(:usiminas_customer) { create(:atua_customer, tenant:, code: 7100, customer_group: usiminas) }
      let!(:gerdau_customer) { create(:atua_customer, tenant:, code: 7200, customer_group: gerdau) }
      let!(:jose_trip) do
        create(:atua_transport_document, tenant:, number: '75001', posted_on: Date.new(2026, 10, 3), plate: 'RVR2C34', freight_cents: 10_000,
                                         driver_code: 10, driver_name: 'JOSE SILVA', taker_code: usiminas_customer.code)
      end
      let!(:maria_usiminas_trip) do
        create(:atua_transport_document, tenant:, number: '75002', posted_on: Date.new(2026, 10, 2), plate: 'RVR8J90', freight_cents: 20_000,
                                         driver_code: 20, driver_name: 'MARIA SOUZA', taker_code: usiminas_customer.code)
      end
      let!(:maria_gerdau_trip) do
        create(:atua_transport_document, tenant:, number: '75003', posted_on: Date.new(2026, 10, 1), plate: 'RVR8J90', freight_cents: 30_000,
                                         driver_code: 20, driver_name: 'MARIA SOUZA', taker_code: gerdau_customer.code)
      end

      let(:table_header) { ['Número', 'Lançado em', 'Origem / Destino', 'Placa', 'Frete', 'Situação', 'Ações'] }
      let(:jose_row) { ['75001 -', '03/10/2026', '- → -', 'RVR2C34', 'R$ 100,00', 'Válido', ''] }
      let(:maria_usiminas_row) { ['75002 -', '02/10/2026', '- → -', 'RVR8J90', 'R$ 200,00', 'Válido', ''] }
      let(:maria_gerdau_row) { ['75003 -', '01/10/2026', '- → -', 'RVR8J90', 'R$ 300,00', 'Válido', ''] }

      scenario 'filters the transport documents by driver' do
        visit transport_documents_path(driver_code: 20)

        expect(Atua::TransportDocument.count).to eq(3)
        expect(html_table_to_rows).to eq([table_header, maria_usiminas_row, maria_gerdau_row])
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Total 2', 'Válidos 2', 'Cancelados 0'])
      end

      scenario 'filters the transport documents by customer group' do
        visit transport_documents_path(customer_group_id: usiminas.id)

        expect(html_table_to_rows).to eq([table_header, jose_row, maria_usiminas_row])
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Total 2', 'Válidos 2', 'Cancelados 0'])
      end

      scenario 'combines the driver and the customer group filters' do
        visit transport_documents_path(driver_code: 20, customer_group_id: usiminas.id)

        expect(html_table_to_rows).to eq([table_header, maria_usiminas_row])
      end

      scenario 'filters the transport documents by customer' do
        visit transport_documents_path(customer_code: gerdau_customer.code)

        expect(html_table_to_rows).to eq([table_header, maria_gerdau_row])
      end

      scenario 'ignores the driver and the customer group filters left blank' do
        visit transport_documents_path(driver_code: '', customer_group_id: '')

        expect(html_table_to_rows).to eq([table_header, jose_row, maria_usiminas_row, maria_gerdau_row])
      end
    end

    context 'when transport documents were launched in a different order than they were issued' do
      let!(:issued_first_launched_last) do
        create(:atua_transport_document, tenant:, number: '74140', issued_at: Time.zone.local(2026, 10, 1, 9), posted_on: Date.new(2026, 10, 20))
      end
      let!(:issued_last_launched_first) do
        create(:atua_transport_document, tenant:, number: '74141', issued_at: Time.zone.local(2026, 10, 15, 9), posted_on: Date.new(2026, 10, 3))
      end
      let!(:issued_between_launched_between) do
        create(:atua_transport_document, tenant:, number: '74142', issued_at: Time.zone.local(2026, 10, 10, 9), posted_on: Date.new(2026, 10, 10))
      end

      scenario 'lists the most recently launched transport documents first' do
        visit transport_documents_path

        expect(Atua::TransportDocument.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Número', 'Lançado em', 'Origem / Destino', 'Placa', 'Frete', 'Situação', 'Ações'],
            ['74140 -', '20/10/2026', '- → -', '-', 'R$ 555,04', 'Válido', ''],
            ['74142 -', '10/10/2026', '- → -', '-', 'R$ 555,04', 'Válido', ''],
            ['74141 -', '03/10/2026', '- → -', '-', 'R$ 555,04', 'Válido', ''],
          ],
        )
      end

      scenario 'filters the transport documents by the launch period instead of the emission' do
        visit transport_documents_path
        fill_in 'Lançados a partir de', with: '2026-10-01'
        fill_in 'Lançados até', with: '2026-10-12'
        click_on 'Aplicar Filtros'

        expect(Atua::TransportDocument.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Número', 'Lançado em', 'Origem / Destino', 'Placa', 'Frete', 'Situação', 'Ações'],
            ['74142 -', '10/10/2026', '- → -', '-', 'R$ 555,04', 'Válido', ''],
            ['74141 -', '03/10/2026', '- → -', '-', 'R$ 555,04', 'Válido', ''],
          ],
        )
      end
    end

    context 'when a transport document has every detail and a manifest' do
      let!(:manifests_resource) { create(:resource, name: 'Manifestos', slug: 'manifests', writable: false) }
      let!(:transport_document) do
        create(:atua_transport_document,
               tenant:, code: 80_842, number: '74130', series: 1, document_kind: 'cte', access_key: '31261000000000000000570010000741301000000000',
               issued_at: Time.zone.local(2026, 10, 1, 16, 45), posted_on: Date.new(2026, 10, 2), cte_status: 'Autorizado', issue_kind: 'Normal',
               service_kind: 'Normal', cfop: 6352, branch_name: 'JR TRANSPORTES',
               sender_name: 'USIMINAS', sender_document: '60.894.730/0001-05', recipient_name: 'FIAT', recipient_document: '16.701.716/0001-56',
               payer_name: 'USIMINAS', payer_document: '60.894.730/0001-05', taker_name: 'USIMINAS',
               origin_city: 'Ipatinga', origin_state: 'MG', destination_city: 'Betim', destination_state: 'MG', plate: 'EXU0F72',
               trailer_plate: 'BEV4G50', driver_name: 'José Motorista', distance_km: BigDecimal('230.5'), weight_kg: BigDecimal('19170'),
               product_name: 'Bobinas de aço', goods_invoice_numbers: %w[1001 1002],
               freight_cents: 555_040, weight_freight_cents: 500_000, value_freight_cents: 30_000, ad_valorem_cents: 5_040, toll_cents: 20_000,
               other_charges_cents: nil, goods_value_cents: 11_259_672, icms_base_cents: 555_040, icms_cents: 66_605,
               raw_data: { 'id_pedagio_ctrc' => 'Cobrar + Pedágio', 'nm_emissao_vale_pedagio' => 'VPO CLIENTE - TARGET' })
      end
      let!(:manifest) { create(:atua_manifest, tenant:, number: '40798', branch_name: 'JR TRANSPORTES', issued_on: Date.new(2026, 10, 1), plate: 'EXU0F72') }
      let!(:link) do
        create(:atua_transport_document_manifest, tenant:, transport_document_code: 80_842, manifest_number: '40798', branch_name: 'JR TRANSPORTES')
      end

      scenario 'shows every detail of the transport document' do
        visit transport_documents_path
        click_on '74130'

        expect(page).to have_current_path(transport_document_path(transport_document))
        expect(page).to have_css('h1.page-title', text: 'CT-e 74130')
        expect(dl_to_hash('#document_data')).to eq(
          'Número' => '74130',
          'Série' => '1',
          'Tipo do documento' => 'CT-e',
          'Chave de acesso' => transport_document.access_key,
          'Emitido em' => '01/10/2026 16:45',
          'Lançado em' => '02/10/2026',
          'Situação' => 'Válido',
          'Situação na SEFAZ' => 'Autorizado',
          'Cancelado em' => '-',
          'Motivo do cancelamento' => '-',
          'Tipo de emissão' => 'Normal',
          'Tipo do serviço' => 'Normal',
          'CFOP' => '6352',
          'Filial' => 'JR TRANSPORTES',
        )
        expect(dl_to_hash('#parties')).to eq(
          'Remetente' => 'USIMINAS 60.894.730/0001-05',
          'Destinatário' => 'FIAT 16.701.716/0001-56',
          'Pagador' => 'USIMINAS 60.894.730/0001-05',
          'Tomador' => 'USIMINAS',
          'Consignatário' => '-',
        )
        expect(dl_to_hash('#transport')).to eq(
          'Origem' => 'Ipatinga/MG',
          'Destino' => 'Betim/MG',
          'Placa' => 'EXU0F72',
          'Placa da carreta' => 'BEV4G50',
          'Motorista' => 'José Motorista',
          'Distância (km)' => '230,50',
          'Peso (kg)' => '19.170,00',
          'Produto' => 'Bobinas de aço',
          'Notas fiscais' => '1001, 1002',
        )
        expect(dl_to_hash('#values')).to eq(
          'Frete' => 'R$ 5.550,40',
          'Frete peso' => 'R$ 5.000,00',
          'Frete valor' => 'R$ 300,00',
          'Ad valorem' => 'R$ 50,40',
          'Pedágio' => 'R$ 200,00 Fora do frete',
          'Pedágio na Atua' => 'Cobrar + Pedágio',
          'Emissão do vale pedágio' => 'VPO CLIENTE - TARGET',
          'Outras cobranças' => '-',
          'Valor da mercadoria' => 'R$ 112.596,72',
          'Base do ICMS' => 'R$ 5.550,40',
          'ICMS' => 'R$ 666,05',
        )
        expect(html_table_to_rows(table: find_by_id('transport_document_manifests'))).to eq(
          [
            ['Número', 'Emitido em', 'Placa', 'Situação'],
            ['40798', '01/10/2026', 'EXU0F72', 'Válido'],
          ],
        )
      end

      scenario 'opens the manifest of the transport document' do
        visit transport_document_path(transport_document)
        click_on '40798'

        expect(page).to have_current_path(manifest_path(manifest))
      end

      scenario 'tells that there is no empty leg to reach the transport document' do
        visit transport_document_path(transport_document)

        expect(EmptyLeg.count).to eq(0)
        expect(page).to have_text('Sem KM vazio, porque este CT-e está na primeira viagem da placa ou o manifesto dele ainda não foi importado.')
      end

      context 'when the empty leg to reach the transport document was calculated' do
        let!(:previous_manifest) { create(:atua_manifest, tenant:, code: 41_100, number: '40700', plate: 'EXU0F72') }
        let!(:origin) do
          create(:location, lookup_key: 'RUA DAS FLORES 10|BETIM|MG', street: 'RUA DAS FLORES 10', city: 'BETIM', state: 'MG',
                            precision_type: 'address')
        end
        let!(:destination) { create(:location, lookup_key: '|IPATINGA|MG', city: 'IPATINGA', state: 'MG', precision_type: 'city') }
        let!(:empty_leg) do
          create(:empty_leg, tenant:, plate: 'EXU0F72', previous_manifest_code: 41_100, next_manifest_code: manifest.code, origin:, destination:,
                             distance_km: BigDecimal('217.44'), precision_type: 'city', calculated_at: Time.zone.local(2026, 10, 1, 18, 5))
        end

        before { create(:empty_leg_transport_document, empty_leg:, tenant:, transport_document_code: 80_842) }

        scenario 'shows the empty kilometers driven to reach the pickup' do
          visit transport_document_path(transport_document)

          expect(EmptyLegTransportDocument.count).to eq(1)
          expect(dl_to_hash("#empty_leg_#{empty_leg.id}")).to eq(
            'Última entrega da viagem anterior' => 'RUA DAS FLORES 10 - BETIM/MG',
            'Primeira coleta desta viagem' => 'IPATINGA/MG',
            'KM vazio' => '217,44 km',
            'Precisão' => 'Centro da cidade',
            'Calculado em' => '01/10/2026 18:05',
          )
          expect(page).to have_no_css("#empty_leg_#{empty_leg.id}", text: '40700')
        end
      end

      context 'with access to the freight expenses' do
        let!(:freight_expenses_resource) { create(:resource, name: 'Despesas de frete', slug: 'freight_expenses', writable: false) }

        let!(:atua_expense) do
          create(:atua_expense, tenant:, history_name: 'DESCARGA - CHAPA', total_cents: 35_000, cost_object: transport_document)
        end

        context 'when the freight has a commission' do
          let!(:freight_expense) do
            create(:freight_expense, tenant:, transport_document:, base_cents: 488_435, icms_cents: 66_605, amount_cents: 9_769)
          end
          let!(:tonnage_expense) { create(:freight_expense, :tonnage, tenant:, transport_document:) }
          let!(:insurance_expense) do
            create(:freight_expense, :insurance, tenant:, transport_document:, base_cents: 1_393_502,
                                                 iof_percentage: BigDecimal('7.38'), iof_cents: 23, amount_cents: 330)
          end

          scenario 'shows the net freight without discounting a toll that is outside the gross freight' do
            visit transport_document_path(transport_document)

            expect(FreightExpense.count).to eq(3)
            expect(dl_to_hash('#transport_document_net_freight')).to eq(
              'Frete bruto' => 'R$ 5.550,40',
              '(−) Comissões' => 'R$ 97,69',
              '(−) Custos por tonelada' => 'R$ 408,53',
              '(−) Seguro da carga' => 'R$ 3,30',
              '(−) Forro de lona' => 'R$ 0,00',
              '(−) Combustível' => 'R$ 0,00',
              '(−) Despesas do frete na Atua' => 'R$ 350,00',
              '(−) Pedágio incluso no frete' => 'R$ 0,00',
              '(=) Frete líquido' => 'R$ 4.690,88',
              'Pedágio fora do frete (não descontado)' => 'R$ 200,00',
            )
          end

          scenario 'lists the commission, the tonnage cost and the cargo insurance of the freight with the total' do
            visit transport_document_path(transport_document)

            expect(transport_document.freight_expenses.count).to eq(3)
            expect(html_table_to_rows(table: find_by_id('transport_document_freight_expenses'))).to eq(
              [
                ['Tipo', 'Regra ou custo', 'Base de cálculo', 'ICMS deduzido da base', 'Taxa', 'Valor'],
                ['Comissão', 'Nacional', 'R$ 4.884,35', 'R$ 666,05', '2,00%', 'R$ 97,69'],
                ['Custo por tonelada', 'Brasiltec – Cubatão/SP (Cubatão)', '32,500 t', '-', 'R$ 12,57/t', 'R$ 408,53'],
                ['Seguro da carga', 'Alíquota de seguro (internacional, com IOF de R$ 0,23)', 'R$ 13.935,02', '-', '0,022%', 'R$ 3,30'],
              ],
            )
            expect(page).to have_css('#transport_document_freight_expenses_total', text: 'Total das despesas do frete R$ 509,52')
          end
        end

        context 'when the freight has no commission' do
          scenario 'does not show the freight expenses card' do
            visit transport_document_path(transport_document)

            expect(FreightExpense.count).to eq(0)
            expect(page).to have_css('#transport_document_net_freight')
            expect(page).to have_no_css('#transport_document_freight_expenses')
          end
        end
      end

      scenario 'does not show the net freight without access to the freight expenses' do
        visit transport_document_path(transport_document)

        expect(page).to have_css('h1.page-title', text: 'CT-e 74130')
        expect(page).to have_no_css('#transport_document_net_freight')
        expect(page).to have_no_css('#transport_document_freight_expenses')
      end

      context 'with access to the expenses' do
        let!(:expenses_resource) { create(:resource, name: 'Despesas', slug: 'expenses', writable: false) }

        scenario 'tells that there are no expenses linked to the transport document' do
          visit transport_document_path(transport_document)

          expect(Atua::Expense.count).to eq(0)
          expect(page).to have_text('Nenhuma despesa vinculada a este CT-e.')
        end

        context 'when the transport document has expenses' do
          let!(:toll) do
            create(:atua_expense, tenant:, code: 590_401, posted_at: Time.zone.local(2026, 10, 2, 7), posted_on: Date.new(2026, 10, 2),
                                  history_name: 'PEDAGIO', payee_name: 'VIA 040', total_cents: 15_000, cost_object: transport_document)
          end
          let!(:unload) do
            create(:atua_expense, tenant:, code: 590_402, posted_at: Time.zone.local(2026, 10, 3, 15), posted_on: Date.new(2026, 10, 3),
                                  history_name: 'DESCARGA - CHAPA', payee_name: nil, total_cents: 35_000, cost_object: transport_document)
          end

          before do
            truck = create(:atua_vehicle, tenant:, plate: 'EXU0F72')
            create(:atua_expense, tenant:, history_name: 'PNEUS', plate: 'EXU0F72', cost_object: truck)
            create(:atua_expense, tenant:, history_name: 'REMOVIDA', cost_object: transport_document, removed_from_atua_at: Time.current)
          end

          scenario 'lists the expenses of the freight with the total' do
            visit transport_document_path(transport_document)

            expect(Atua::Expense.count).to eq(4)
            expect(html_table_to_rows(table: find_by_id('transport_document_expenses'))).to eq(
              [
                ['Histórico', 'Lançado em', 'Favorecido', 'Valor total'],
                ['DESCARGA - CHAPA', '03/10/2026', '-', 'R$ 350,00'],
                ['PEDAGIO', '02/10/2026', 'VIA 040', 'R$ 150,00'],
              ],
            )
            expect(page).to have_css('#transport_document_expenses_total', text: 'Total de despesas R$ 500,00')
          end

          scenario 'opens an expense of the freight' do
            visit transport_document_path(transport_document)
            click_on 'PEDAGIO'

            expect(page).to have_current_path(expense_path(toll))
          end
        end
      end
    end

    context 'when transport documents carry tolls inside the freight and none at all' do
      let!(:freight_expenses_resource) { create(:resource, name: 'Despesas de frete', slug: 'freight_expenses', writable: false) }
      let!(:included) do
        create(:atua_transport_document, tenant:, number: '74140', freight_cents: 1_000_000, weight_freight_cents: 850_000, toll_cents: 30_000,
                                         icms_cents: 120_000, raw_data: { 'id_pedagio_ctrc' => 'Incluso', 'nm_emissao_vale_pedagio' => 'SEM VALE PEDÁGIO' })
      end
      let!(:without_toll) do
        create(:atua_transport_document, tenant:, number: '74141', freight_cents: 300_000, weight_freight_cents: 300_000, toll_cents: 0)
      end

      scenario 'highlights the toll included in the freight and discounts it from the net freight' do
        visit transport_document_path(included)

        expect(Atua::TransportDocument.count).to eq(2)
        expect(dl_to_hash('#values')).to eq(
          'Frete' => 'R$ 10.000,00',
          'Frete peso' => 'R$ 8.500,00',
          'Frete valor' => '-',
          'Ad valorem' => '-',
          'Pedágio' => 'R$ 300,00 Incluso no frete',
          'Pedágio na Atua' => 'Incluso',
          'Emissão do vale pedágio' => 'SEM VALE PEDÁGIO',
          'Outras cobranças' => '-',
          'Valor da mercadoria' => '-',
          'Base do ICMS' => '-',
          'ICMS' => 'R$ 1.200,00',
        )
        expect(dl_to_hash('#transport_document_net_freight')).to eq(
          'Frete bruto' => 'R$ 10.000,00',
          '(−) Comissões' => 'R$ 0,00',
          '(−) Custos por tonelada' => 'R$ 0,00',
          '(−) Seguro da carga' => 'R$ 0,00',
          '(−) Forro de lona' => 'R$ 0,00',
          '(−) Combustível' => 'R$ 0,00',
          '(−) Despesas do frete na Atua' => 'R$ 0,00',
          '(−) Pedágio incluso no frete' => 'R$ 300,00',
          '(=) Frete líquido' => 'R$ 9.700,00',
        )
      end

      scenario 'marks a transport document without toll' do
        visit transport_document_path(without_toll)

        expect(dl_to_hash('#values')).to eq(
          'Frete' => 'R$ 3.000,00',
          'Frete peso' => 'R$ 3.000,00',
          'Frete valor' => '-',
          'Ad valorem' => '-',
          'Pedágio' => 'R$ 0,00 Sem pedágio',
          'Pedágio na Atua' => '-',
          'Emissão do vale pedágio' => '-',
          'Outras cobranças' => '-',
          'Valor da mercadoria' => '-',
          'Base do ICMS' => '-',
          'ICMS' => '-',
        )
        expect(page).to have_no_text('Pedágio fora do frete')
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:transport_document) { create(:atua_transport_document, tenant:, number: '74130') }

    before { login_as(operator, scope: :user) }

    context 'without access to the transport documents' do
      scenario 'is sent back with an access denied message' do
        visit transport_documents_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end

      scenario 'cannot open a transport document' do
        visit transport_document_path(transport_document)

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the transport documents' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'lists and opens the transport documents' do
        visit transport_documents_path

        expect(Atua::TransportDocument.count).to eq(1)
        expect(html_table_to_rows.size).to eq(2)

        click_on '74130'

        expect(page).to have_current_path(transport_document_path(transport_document))
      end

      context 'when the transport document has a manifest' do
        let!(:manifest) { create(:atua_manifest, tenant:, number: '40798', branch_name: transport_document.branch_name) }

        before do
          create(:atua_transport_document_manifest, tenant:, transport_document_code: transport_document.code, manifest_number: manifest.number,
                                                    branch_name: transport_document.branch_name)
        end

        scenario 'does not link the manifests without access to them' do
          visit transport_document_path(transport_document)

          expect(html_table_to_rows(table: find_by_id('transport_document_manifests'))).to eq(
            [
              ['Número', 'Emitido em', 'Placa', 'Situação'],
              ['40798', '01/10/2026', 'RHJ4E07', 'Válido'],
            ],
          )
          expect(page).to have_no_link('40798')
        end
      end

      context 'when the transport document has expenses' do
        let!(:toll) { create(:atua_expense, tenant:, history_name: 'PEDAGIO', cost_object: transport_document) }

        scenario 'does not show the expenses without access to them' do
          visit transport_document_path(transport_document)

          expect(Atua::Expense.count).to eq(1)
          expect(page).to have_no_text('Despesas do frete')
          expect(page).to have_no_text('PEDAGIO')
        end
      end
    end
  end

  context 'on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:transport_document) { create(:atua_transport_document, tenant:, number: '74130', plate: 'EXU0F72') }

    before do
      login_as(admin, scope: :user)
      use_mobile_screen
    end

    context 'when transport documents have different drivers and customer groups' do
      let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
      let!(:gerdau) { create(:customer_group, tenant:, name: 'GERDAU') }
      let!(:other_group) { create(:customer_group, tenant: other_tenant, name: 'ARCELOR') }
      let!(:usiminas_customer) { create(:atua_customer, tenant:, code: 7100, customer_group: usiminas) }
      let!(:maria_trip) do
        create(:atua_transport_document, tenant:, number: '75002', plate: 'RVR8J90', driver_code: 20, driver_name: 'MARIA SOUZA', taker_code: usiminas_customer.code)
      end
      let!(:jose_trip) { create(:atua_transport_document, tenant:, number: '75001', plate: 'RVR2C34', driver_code: 10, driver_name: 'JOSE SILVA', taker_code: 7200) }
      let!(:stranger_trip) { create(:atua_transport_document, tenant: other_tenant, number: '75003', driver_code: 30, driver_name: 'PEDRO LIMA') }

      scenario 'searches the drivers and the customer groups of the tenant and filters by them' do
        visit transport_documents_path
        find(:link, href: '#filtersModal').click

        within('#driver_code_select') do
          find('.select2-trigger').click
          expect(all('.select2-option').map(&:text)).to eq(['JOSE SILVA', 'MARIA SOUZA'])

          find('.select2-search').fill_in(with: 'mar')
          find('.select2-option', text: 'MARIA SOUZA').click
        end

        within('#customer_group_id_select') do
          find('.select2-trigger').click
          expect(all('.select2-option').map(&:text)).to eq(%w[GERDAU USIMINAS])

          find('.select2-option', text: 'USIMINAS').click
        end

        expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
        click_on 'Aplicar Filtros'

        expect(page).to have_current_path(/driver_code=20&customer_group_id=\d+/)
        expect(page).to have_link(href: transport_document_path(maria_trip))
        expect(page).to have_no_link(href: transport_document_path(jose_trip))
        expect(page).to have_css('#driver_code_select .select2-single-value', text: 'MARIA SOUZA', visible: :all)
        expect(page).to have_css('#customer_group_id_select .select2-single-value', text: 'USIMINAS', visible: :all)
      end

      context 'when the customers belong to different groups' do
        let!(:usiminas_branch) { create(:atua_customer, tenant:, code: 7101, name: 'USIMINAS CUBATAO', document: '12.345.678/0001-90', customer_group: usiminas) }
        let!(:gerdau_customer) { create(:atua_customer, tenant:, code: 7200, name: 'GERDAU OURO BRANCO', document: '98.765.432/0001-10', customer_group: gerdau) }
        let!(:stranger_customer) { create(:atua_customer, tenant: other_tenant, code: 7300, name: 'CLIENTE DE OUTRA') }
        let!(:branch_trip) { create(:atua_transport_document, tenant:, number: '75004', taker_code: usiminas_branch.code) }

        scenario 'lists every customer of the tenant and searches them by name or digits of the document' do
          visit transport_documents_path
          find(:link, href: '#filtersModal').click

          within('#customer_code_select') do
            find('.select2-trigger').click
            options = all('.select2-option').map(&:text)
            expect(options).to include('GERDAU OURO BRANCO - 98.765.432/0001-10', 'USIMINAS CUBATAO - 12.345.678/0001-90')
            expect(options.size).to eq(tenant.atua_customers.count)
            expect(options).not_to include(a_string_matching('CLIENTE DE OUTRA'))

            find('.select2-search').fill_in(with: '12345678')
            expect(all('.select2-option').map(&:text)).to eq(['USIMINAS CUBATAO - 12.345.678/0001-90'])

            find('.select2-search').fill_in(with: 'ouro branco')
            expect(all('.select2-option').map(&:text)).to eq(['GERDAU OURO BRANCO - 98.765.432/0001-10'])
            find('.select2-option', text: 'GERDAU OURO BRANCO').click
          end

          click_on 'Aplicar Filtros'

          expect(page).to have_current_path(/customer_code=7200/)
          expect(page).to have_no_link(href: transport_document_path(branch_trip))
        end

        scenario 'lists only the customers of the selected group and drops a customer outside of it' do
          visit transport_documents_path(customer_code: gerdau_customer.code)
          find(:link, href: '#filtersModal').click

          expect(page).to have_css('#customer_code_select .select2-single-value', text: 'GERDAU OURO BRANCO', visible: :all)

          within('#customer_group_id_select') do
            find('.select2-trigger').click
            find('.select2-option', text: 'USIMINAS').click
          end

          expect(page).to have_no_css('#customer_code_select .select2-single-value', visible: :all)

          within('#customer_code_select') do
            find('.select2-trigger').click
            options = all('.select2-option').map(&:text)
            expect(options).to include('USIMINAS CUBATAO - 12.345.678/0001-90')
            expect(options.size).to eq(usiminas.customers.count)
            expect(options).not_to include(a_string_matching('GERDAU'))
          end
        end

        scenario 'filters by the selected group and customer' do
          visit transport_documents_path(customer_group_id: usiminas.id, customer_code: usiminas_branch.code)
          find(:link, href: '#filtersModal').click

          expect(page).to have_css('#customer_code_select .select2-single-value', text: 'USIMINAS CUBATAO', visible: :all)
          expect(page).to have_link(href: transport_document_path(branch_trip))
          expect(page).to have_no_link(href: transport_document_path(maria_trip))
        end
      end
    end

    context 'when the transport document has expenses' do
      let!(:expenses_resource) { create(:resource, name: 'Despesas', slug: 'expenses', writable: false) }

      before do
        create(:atua_expense, tenant:, history_name: 'PEDAGIO', payee_name: 'VIA 040', total_cents: 15_000, cost_object: transport_document)
      end

      scenario 'keeps only the history and the total of the expenses without horizontal scroll' do
        visit transport_document_path(transport_document)

        expect(page).to have_css('#transport_document_expenses td', text: 'R$ 150,00')
        expect(page).to have_no_css('#transport_document_expenses th', text: 'Favorecido')
        expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      end
    end

    scenario 'keeps only the essential columns without horizontal scroll' do
      visit transport_documents_path

      expect(page).to have_link('74130')
      expect(page).to have_no_css('th', text: 'Placa')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end

    context 'when the empty leg to reach the transport document was calculated' do
      let!(:location) do
        create(:location, lookup_key: 'AVENIDA DAS INDUSTRIAS 1500|SANTANA DE PARNAIBA|SP', street: 'AVENIDA DAS INDUSTRIAS 1500',
                          city: 'SANTANA DE PARNAIBA', state: 'SP')
      end
      let!(:empty_leg) { create(:empty_leg, tenant:, origin: location, destination: location) }

      before { create(:empty_leg_transport_document, empty_leg:, tenant:, transport_document_code: transport_document.code) }

      scenario 'stacks the empty leg details without horizontal scroll' do
        visit transport_document_path(transport_document)

        expect(page).to have_css("#empty_leg_#{empty_leg.id}", text: '48,20 km')
        expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      end
    end
  end

  context 'on a tablet', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }

    before do
      login_as(admin, scope: :user)
      use_mobile_screen(width: 820, height: 1180)
    end

    scenario 'stacks the period filters one below the other' do
      visit transport_documents_path
      find(:link, href: '#filtersModal').click

      within('#filtersModal') { expect(page).to have_field('Lançados até') }
      start_top = page.evaluate_script("document.getElementById('start_date').getBoundingClientRect().top")
      end_top = page.evaluate_script("document.getElementById('end_date').getBoundingClientRect().top")
      expect(end_top).to be > start_top
    end
  end
end
