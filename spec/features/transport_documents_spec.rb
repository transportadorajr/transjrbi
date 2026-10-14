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
                                         origin_city: 'Ipatinga', origin_state: 'MG', destination_city: 'Betim', destination_state: 'MG',
                                         plate: 'EXU0F72', freight_cents: 55_504)
      end
      let!(:canceled) do
        create(:atua_transport_document, tenant:, number: '74131', sender_name: 'GERDAU', issued_at: Time.zone.local(2026, 10, 5, 8),
                                         canceled_at: Time.zone.local(2026, 10, 5, 9), plate: 'RHJ4E07', freight_cents: 120_000)
      end
      let!(:removed) { create(:atua_transport_document, tenant:, number: '74132', removed_from_atua_at: Time.current) }
      let!(:stranger) { create(:atua_transport_document, tenant: other_tenant, number: '74133') }

      scenario 'lists the active transport documents of the tenant from the fiscal menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Fiscal'
          click_on 'CT-es'
        end

        expect(page).to have_current_path(transport_documents_path)
        expect(Atua::TransportDocument.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            ['Número', 'Emitido em', 'Origem / Destino', 'Placa', 'Frete', 'Situação', 'Ações'],
            ['74131 GERDAU', '05/10/2026 08:00', '- → -', 'RHJ4E07', 'R$ 1.200,00', 'Cancelado', ''],
            ['74130 USIMINAS', '01/10/2026 16:45', 'Ipatinga/MG → Betim/MG', 'EXU0F72', 'R$ 555,04', 'Válido', ''],
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
            ['Número', 'Emitido em', 'Origem / Destino', 'Placa', 'Frete', 'Situação', 'Ações'],
            ['74130 USIMINAS', '01/10/2026 16:45', 'Ipatinga/MG → Betim/MG', 'EXU0F72', 'R$ 555,04', 'Válido', ''],
          ],
        )
      end

      scenario 'filters the transport documents by plate, period and situation' do
        visit transport_documents_path
        fill_in 'Placa', with: 'rhj-4e07'
        fill_in 'Emitidos a partir de', with: '2026-10-02'
        fill_in 'Emitidos até', with: '2026-10-31'
        select 'Cancelado', from: 'Situação'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Número', 'Emitido em', 'Origem / Destino', 'Placa', 'Frete', 'Situação', 'Ações'],
            ['74131 GERDAU', '05/10/2026 08:00', '- → -', 'RHJ4E07', 'R$ 1.200,00', 'Cancelado', ''],
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

    context 'when a transport document has every detail and a manifest' do
      let!(:manifests_resource) { create(:resource, name: 'Manifestos', slug: 'manifests', writable: false) }
      let!(:transport_document) do
        create(:atua_transport_document,
               tenant:, code: 80_842, number: '74130', series: 1, document_kind: 'cte', access_key: '31261000000000000000570010000741301000000000',
               issued_at: Time.zone.local(2026, 10, 1, 16, 45), cte_status: 'Autorizado', issue_kind: 'Normal', service_kind: 'Normal',
               cfop: 6352, branch_name: 'JR TRANSPORTES',
               sender_name: 'USIMINAS', sender_document: '60.894.730/0001-05', recipient_name: 'FIAT', recipient_document: '16.701.716/0001-56',
               payer_name: 'USIMINAS', payer_document: '60.894.730/0001-05', taker_name: 'USIMINAS',
               origin_city: 'Ipatinga', origin_state: 'MG', destination_city: 'Betim', destination_state: 'MG', plate: 'EXU0F72',
               trailer_plate: 'BEV4G50', driver_name: 'José Motorista', distance_km: BigDecimal('230.5'), weight_kg: BigDecimal('19170'),
               product_name: 'Bobinas de aço', goods_invoice_numbers: %w[1001 1002],
               freight_cents: 555_040, weight_freight_cents: 500_000, value_freight_cents: 30_000, ad_valorem_cents: 5_040, toll_cents: 20_000,
               other_charges_cents: nil, goods_value_cents: 11_259_672, icms_base_cents: 555_040, icms_cents: 66_605)
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
          'Pedágio' => 'R$ 200,00',
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

      scenario 'does not link the manifests without access to them' do
        create(:atua_manifest, tenant:, number: '40798', branch_name: transport_document.branch_name)
        create(:atua_transport_document_manifest, tenant:, transport_document_code: transport_document.code, manifest_number: '40798',
                                                  branch_name: transport_document.branch_name)

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
  end

  context 'on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:transport_document) { create(:atua_transport_document, tenant:, number: '74130', plate: 'EXU0F72') }

    before do
      login_as(admin, scope: :user)
      use_mobile_screen
    end

    scenario 'keeps only the essential columns without horizontal scroll' do
      visit transport_documents_path

      expect(page).to have_link('74130')
      expect(page).to have_no_css('th', text: 'Placa')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
