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
        create(:atua_manifest, :with_transport_document, tenant:, number: '40772', branch_name: 'JR TRANSPORTES', issued_on: Date.new(2026, 10, 1),
                                                         departure_on: Date.new(2026, 10, 2), plate: 'RHJ4E07', status: 'Encerrado', goods_value_cents: 11_259_672)
      end
      let!(:canceled) do
        create(:atua_manifest, tenant:, number: '40780', branch_name: 'TRANSJR SABARA', issued_on: Date.new(2026, 10, 6),
                               departure_on: nil, plate: 'EXU0F72', status: 'Cancelado', goods_value_cents: nil)
      end
      let!(:removed) { create(:atua_manifest, tenant:, number: '40790', removed_from_atua_at: Time.current) }
      let!(:stranger) { create(:atua_manifest, tenant: other_tenant, number: '40791') }

      scenario 'lists only the valid active manifests of the tenant from the tax menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Fiscal'
          click_on 'Manifestos'
        end

        expect(page).to have_current_path(manifests_path)
        expect(Atua::Manifest.count).to eq(4)
        expect(Atua::TransportDocument.count).to eq(1)
        expect(html_table_to_rows).to eq(
          [
            ['MDF-e', 'Placa', 'Motorista', 'Origem', 'Destino', 'Peso (kg)', 'Grupo de clientes', 'KM rodado', 'Bruto/km', 'Ações'],
            ['40772 JR TRANSPORTES KM rodado - Bruto/km - Grupo de clientes - Origem - Destino -', 'RHJ4E07', '-', '-', '-', '-', '-', '-', '-', ''],
          ],
        )
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Manifestos válidos 1'])
        expect(page).to have_text('1 registro')
        expect(page).to have_link(href: manifest_path(closed), title: 'Visualizar')
        expect(page).to have_no_text('40780')
        expect(page).to have_no_text('40790')
        expect(page).to have_no_text('40791')
      end

      scenario 'filters the manifests by number' do
        create(:atua_manifest, :with_transport_document, tenant:, number: '40773', plate: 'EXU0F72')

        visit manifests_path
        fill_in 'Número do manifesto', with: '40772'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['MDF-e', 'Placa', 'Motorista', 'Origem', 'Destino', 'Peso (kg)', 'Grupo de clientes', 'KM rodado', 'Bruto/km', 'Ações'],
            ['40772 JR TRANSPORTES KM rodado - Bruto/km - Grupo de clientes - Origem - Destino -', 'RHJ4E07', '-', '-', '-', '-', '-', '-', '-', ''],
          ],
        )
      end

      scenario 'filters the manifests by plate and period without offering the situation' do
        create(:atua_manifest, :with_transport_document, tenant:, number: '40773', branch_name: 'TRANSJR SABARA', issued_on: Date.new(2026, 10, 6), plate: 'EXU0F72')

        visit manifests_path
        expect(page).to have_field('Placa')
        expect(page).to have_no_select('Situação')
        fill_in 'Placa', with: 'exu 0f72'
        fill_in 'Emitidos a partir de', with: '2026-10-02'
        fill_in 'Emitidos até', with: '2026-10-31'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['MDF-e', 'Placa', 'Motorista', 'Origem', 'Destino', 'Peso (kg)', 'Grupo de clientes', 'KM rodado', 'Bruto/km', 'Ações'],
            ['40773 TRANSJR SABARA KM rodado - Bruto/km - Grupo de clientes - Origem - Destino -', 'EXU0F72', '-', '-', '-', '-', '-', '-', '-', ''],
          ],
        )
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Manifestos válidos 1'])
      end

      scenario 'ignores a canceled situation left in the address' do
        visit manifests_path(status: 'canceled')

        expect(page).to have_text('40772')
        expect(page).to have_no_text('40780')
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

    context 'when the manifests have transport documents of different drivers, trucks, products and customers' do
      let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
      let!(:gerdau) { create(:customer_group, tenant:, name: 'GERDAU') }
      let!(:usiminas_customer) { create(:atua_customer, tenant:, code: 7100, name: 'USIMINAS IPATINGA', document: nil, customer_group: usiminas) }
      let!(:gerdau_customer) { create(:atua_customer, tenant:, code: 7200, name: 'GERDAU OURO BRANCO', customer_group: gerdau) }
      let!(:steel) { create(:product_group, tenant:, name: 'SIDERÚRGICO') }
      let!(:coil) { create(:product_subgroup, tenant:, parent: steel, name: 'BOBINA') }
      let!(:rebar) { create(:product_subgroup, tenant:, parent: steel, name: 'VERGALHÃO') }
      let!(:rodotrem) { create(:truck_group, tenant:, name: 'Rodotrem', axles: [9]) }
      let!(:inactive_customer_group) { create(:customer_group, tenant:, name: 'ARCELOR', activated_at: nil) }
      let!(:inactive_product_group) { create(:product_group, tenant:, name: 'CELULOSE E PAPEL', activated_at: nil) }
      let!(:ls) { create(:truck_group, :ls, tenant:) }
      let!(:jose_trip) do
        create(:atua_manifest, tenant:, code: 41_401, number: '40801', branch_name: 'JR', issued_on: Date.new(2026, 10, 1), plate: 'RHJ4E07')
      end
      let!(:maria_trip) do
        create(:atua_manifest, tenant:, code: 41_402, number: '40802', branch_name: 'JR', issued_on: Date.new(2026, 10, 2), plate: 'EXU0F72')
      end
      let(:table_header) { ['MDF-e', 'Placa', 'Motorista', 'Origem', 'Destino', 'Peso (kg)', 'Grupo de clientes', 'KM rodado', 'Bruto/km', 'Ações'] }
      let(:jose_row) { ['40801 JR KM rodado - Bruto/km - Grupo de clientes USIMINAS Origem - Destino -', 'RHJ4E07', 'JOSE SILVA', '-', '-', '-', 'USIMINAS', '-', '-', ''] }
      let(:maria_row) { ['40802 JR KM rodado - Bruto/km - Grupo de clientes GERDAU Origem - Destino -', 'EXU0F72', 'MARIA SOUZA', '-', '-', '-', 'GERDAU', '-', '-', ''] }

      def add_document(manifest, number, **attributes)
        create(:atua_transport_document, tenant:, number:, series: 1, branch_name: 'JR', **attributes)
        create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: number, transport_document_series: 1,
                                        branch_name: 'JR')
      end

      before do
        add_document(jose_trip, '1', driver_code: 10, driver_name: 'JOSE SILVA', axles: 9, taker_code: usiminas_customer.code,
                                     product_group_id: coil.id, freight_cents: 100_000)
        add_document(maria_trip, '2', driver_code: 20, driver_name: 'MARIA SOUZA', axles: 6, taker_code: gerdau_customer.code,
                                      product_group_id: rebar.id, freight_cents: 200_000)
      end

      scenario 'offers the drivers and only the active truck, product and customer groups on the filters' do
        visit manifests_path

        expect(page).to have_select('Tipo de conjunto', options: ['Todos', '6 eixos', 'Rodotrem'])
        expect(all('#driver_code_select [role="option"]', visible: :all).map { |option| option.text(:all) }).to eq(['JOSE SILVA', 'MARIA SOUZA'])
        expect(all('#product_group_id_select [role="option"]', visible: :all).map { |option| option.text(:all) }).to eq(['SIDERÚRGICO'])
        expect(all('#product_id_select [role="option"]', visible: :all).map { |option| option.text(:all) })
          .to eq(['BOBINA (SIDERÚRGICO)', 'VERGALHÃO (SIDERÚRGICO)'])
        expect(all('#customer_group_id_select [role="option"]', visible: :all).map { |option| option.text(:all) }).to eq(%w[GERDAU USIMINAS])
      end

      scenario 'filters the manifests by the driver of the transport documents' do
        visit manifests_path(driver_code: 20)

        expect(Atua::Manifest.count).to eq(2)
        expect(html_table_to_rows).to eq([table_header, maria_row])
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Manifestos válidos 1'])
      end

      scenario 'filters the manifests by the truck group of the transport documents' do
        visit manifests_path
        select 'Rodotrem', from: 'Tipo de conjunto'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq([table_header, jose_row])
      end

      scenario 'lists no manifest for a truck group of another tenant' do
        visit manifests_path(truck_group_id: create(:truck_group, tenant: other_tenant).id)

        expect(page).to have_text('Nenhum registro encontrado')
      end

      scenario 'filters the manifests by the product group of the transport documents' do
        visit manifests_path(product_group_id: steel.id)

        expect(html_table_to_rows).to eq([table_header, maria_row, jose_row])
      end

      scenario 'filters the manifests by the product of the transport documents' do
        visit manifests_path(product_id: rebar.id, sort: 'gross_per_km', direction: 'desc')

        expect(Atua::Manifest.count).to eq(2)
        expect(html_table_to_rows).to eq([table_header, maria_row])
        expect(page).to have_field('product_id', type: :hidden, with: rebar.id.to_s)
      end

      scenario 'filters the manifests by the customer group and by the customer of the transport documents' do
        visit manifests_path(customer_group_id: gerdau.id)

        expect(html_table_to_rows).to eq([table_header, maria_row])

        visit manifests_path(customer_code: usiminas_customer.code)

        expect(html_table_to_rows).to eq([table_header, jose_row])
      end

      scenario 'ignores the blank filters' do
        visit manifests_path(driver_code: '', truck_group_id: '', product_group_id: '', product_id: '', customer_group_id: '', customer_code: '')

        expect(html_table_to_rows).to eq([table_header, maria_row, jose_row])
      end

      scenario 'lists only the products of the selected product group' do
        create(:product_subgroup, tenant:, parent: create(:product_group, tenant:, name: 'FARINHA'), name: 'FARINHA DE TRIGO')

        visit manifests_path(product_group_id: steel.id)

        expect(all('#product_id_select [role="option"]', visible: :all).map { |option| option.text(:all) })
          .to eq(['BOBINA (SIDERÚRGICO)', 'VERGALHÃO (SIDERÚRGICO)'])

        visit product_options_manifests_path(product_group_id: steel.id, product_id: rebar.id)

        expect(all('#product_id_select [role="option"]', visible: :all).map { |option| option.text(:all) })
          .to eq(['BOBINA (SIDERÚRGICO)', 'VERGALHÃO (SIDERÚRGICO)'])
        expect(page).to have_field('product_id', type: :hidden, with: rebar.id.to_s)
      end

      scenario 'lists only the customers of the selected group' do
        visit customer_options_manifests_path(customer_group_id: usiminas.id, customer_code: gerdau_customer.code)

        expect(all('#customer_code_select [role="option"]', visible: :all).map { |option| option.text(:all) }).to eq(['USIMINAS IPATINGA'])
        expect(page).to have_no_css('#customer_code_select .select2-single-value', visible: :all)
      end
    end

    context 'when a manifest has transport documents from several cities' do
      let!(:manifest) { create(:atua_manifest, tenant:, code: 41_300, number: '40800', branch_name: 'JR', plate: 'RHJ4E07') }

      def add_document(number, origin:, destination:, **attributes)
        create(:atua_transport_document, tenant:, number:, series: 1, branch_name: 'JR', **attributes)
        create(:atua_manifest_document, tenant:, manifest_code: 41_300, transport_document_number: number, transport_document_series: 1,
                                        branch_name: 'JR', origin_city: origin, origin_state: 'MG', destination_city: destination, destination_state: 'SP')
      end

      before do
        add_document('1', origin: 'Ipatinga', destination: 'Santos', freight_cents: 600_000)
        add_document('2', origin: 'Ipatinga', destination: 'Cubatão', freight_cents: 300_000)
        add_document('3', origin: 'Betim', destination: 'Santos', freight_cents: 100_000)
        add_document('4', origin: 'Sabará', destination: 'Campinas', freight_cents: 900_000, canceled_at: Time.current)
      end

      scenario 'shows every city once' do
        visit manifests_path

        expect(Atua::Manifest.count).to eq(1)
        expect(html_table_to_rows).to eq(
          [
            ['MDF-e', 'Placa', 'Motorista', 'Origem', 'Destino', 'Peso (kg)', 'Grupo de clientes', 'KM rodado', 'Bruto/km', 'Ações'],
            ['40800 JR KM rodado - Bruto/km - Grupo de clientes - Origem Ipatinga/MG Betim/MG Destino Santos/SP Cubatão/SP', 'RHJ4E07', '-', 'Ipatinga/MG Betim/MG', 'Santos/SP Cubatão/SP', '-', '-', '-', '-', ''],
          ],
        )
      end

      scenario 'shows the route of the valid transport documents on the details' do
        visit manifest_path(manifest)

        expect(dl_to_hash('#manifest_data')).to include(
          'Origem' => 'Ipatinga/MG Betim/MG',
          'Destino' => 'Santos/SP Cubatão/SP',
        )
      end
    end

    context 'when the manifests have drivers, customers, weights and loaded km' do
      let!(:jose_trip) do
        create(:atua_manifest, tenant:, code: 41_700, number: '40900', branch_name: 'JR', issued_on: Date.new(2026, 10, 1), plate: 'AAA1A11')
      end
      let!(:maria_trip) do
        create(:atua_manifest, tenant:, code: 41_701, number: '40901', branch_name: 'JR', issued_on: Date.new(2026, 10, 2), plate: 'BBB2B22')
      end
      let!(:steel_document) do
        create(:atua_transport_document, tenant:, number: '901', series: 1, branch_name: 'JR', driver_name: 'JOSE SILVA', taker_name: 'USIMINAS',
                                         freight_cents: 600_000)
      end

      def add_document(manifest, number, weight_kg:, **distances)
        create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: number, transport_document_series: 1,
                                        branch_name: 'JR', weight_kg:, **distances)
      end

      before do
        create(:atua_transport_document, tenant:, number: '902', series: 1, branch_name: 'JR', driver_name: 'JOSE SILVA', taker_name: 'GERDAU',
                                         freight_cents: 400_000)
        create(:atua_transport_document, tenant:, number: '903', series: 1, branch_name: 'JR', driver_name: 'MARIA SOUZA', taker_name: 'USIMINAS',
                                         freight_cents: 300_000)
        add_document(jose_trip, '901', weight_kg: BigDecimal('20000'), calculated_distance_km: BigDecimal('500'))
        add_document(jose_trip, '902', weight_kg: BigDecimal('10000'), document_distance_km: BigDecimal('400'))
        add_document(maria_trip, '903', weight_kg: BigDecimal('5000'), document_distance_km: BigDecimal('100'))
      end

      scenario 'lists the driver, the weight, the customers and the gross freight per loaded km of each trip' do
        visit manifests_path

        expect(Atua::Manifest.count).to eq(2)
        expect(html_table_to_rows).to eq(
          [
            ['MDF-e', 'Placa', 'Motorista', 'Origem', 'Destino', 'Peso (kg)', 'Grupo de clientes', 'KM rodado', 'Bruto/km', 'Ações'],
            ['40901 JR KM rodado 100,00 km Bruto/km R$ 30,00 Grupo de clientes USIMINAS Origem - Destino -', 'BBB2B22', 'MARIA SOUZA', '-', '-', '5.000,00', 'USIMINAS', '100,00 km', 'R$ 30,00', ''],
            ['40900 JR KM rodado 500,00 km Bruto/km R$ 20,00 Grupo de clientes USIMINAS GERDAU Origem - Destino -', 'AAA1A11', 'JOSE SILVA', '-', '-', '30.000,00', 'USIMINAS GERDAU', '500,00 km', 'R$ 20,00', ''],
          ],
        )
      end

      scenario 'sorts the trips by the gross freight per loaded km' do
        visit manifests_path
        within('thead') { click_on 'Bruto/km' }
        within('thead') { click_on 'Bruto/km' }

        expect(all('tbody .table-identity a').map(&:text)).to eq(%w[40900 40901])
      end

      context 'with access to the freight expenses' do
        let!(:freight_expenses_resource) { create(:resource, name: 'Despesas de frete', slug: 'freight_expenses', writable: false) }
        let!(:freight_expense) { create(:freight_expense, tenant:, transport_document: steel_document, amount_cents: 100_000) }

        scenario 'shows and sorts by the net freight per loaded km of each trip' do
          visit manifests_path
          within('thead') { click_on 'Líquido/km' }

          expect(FreightExpense.count).to eq(1)
          expect(html_table_to_rows).to eq(
            [
              ['MDF-e', 'Placa', 'Motorista', 'Origem', 'Destino', 'Peso (kg)', 'Grupo de clientes', 'KM rodado', 'Bruto/km', 'Líquido/km', 'Ações'],
              ['40901 JR KM rodado 100,00 km Bruto/km R$ 30,00 Líquido/km R$ 30,00 Grupo de clientes USIMINAS Origem - Destino -', 'BBB2B22', 'MARIA SOUZA', '-', '-', '5.000,00', 'USIMINAS', '100,00 km', 'R$ 30,00', 'R$ 30,00', ''],
              ['40900 JR KM rodado 500,00 km Bruto/km R$ 20,00 Líquido/km R$ 18,00 Grupo de clientes USIMINAS GERDAU Origem - Destino -', 'AAA1A11', 'JOSE SILVA', '-', '-', '30.000,00', 'USIMINAS GERDAU', '500,00 km', 'R$ 20,00', 'R$ 18,00', ''],
            ],
          )
        end
      end

      scenario 'does not sort by the net freight per loaded km without access to the freight expenses' do
        visit manifests_path(sort: 'net_per_km', direction: 'asc')

        expect(all('tbody .table-identity a').map(&:text)).to eq(%w[40901 40900])
        expect(page).to have_no_css('th', text: 'Líquido/km')
      end
    end

    context 'when no transport document of a manifest was imported from Atua' do
      let!(:manifest) { create(:atua_manifest, tenant:, code: 41_625, number: '38075', branch_name: 'JR TRANSPORTES', plate: 'BEC3D14') }

      before do
        create(:atua_manifest_document, tenant:, manifest_code: 41_625, transport_document_number: '69674', transport_document_series: 1,
                                        branch_name: 'JR TRANSPORTES', freight_cents: 225_105, document_distance_km: BigDecimal('24'))
      end

      scenario 'leaves the manifest out of the listing and of the details' do
        visit manifests_path

        expect(Atua::Manifest.count).to eq(1)
        expect(Atua::TransportDocument.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_text('38075')

        visit manifest_path(manifest)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when one of the transport documents of a manifest was not imported from Atua' do
      let!(:manifest) { create(:atua_manifest, tenant:, code: 41_626, number: '41149', branch_name: 'JR TRANSPORTES', plate: 'BDC8D26') }

      before do
        create(:atua_transport_document, tenant:, number: '74763', series: 1, branch_name: 'JR TRANSPORTES', freight_cents: 198_085)
        create(:atua_manifest_document, tenant:, manifest_code: 41_626, transport_document_number: '74763', transport_document_series: 1,
                                        branch_name: 'JR TRANSPORTES', freight_cents: 198_085, document_distance_km: BigDecimal('500'))
        create(:atua_manifest_document, tenant:, manifest_code: 41_626, transport_document_number: '74764', transport_document_series: 1,
                                        branch_name: 'JR TRANSPORTES', freight_cents: 801_915, document_distance_km: BigDecimal('500'))
      end

      scenario 'adds the freight of the manifest to the gross freight per loaded km' do
        visit manifests_path

        expect(Atua::TransportDocument.count).to eq(1)
        expect(html_table_to_rows).to eq(
          [
            ['MDF-e', 'Placa', 'Motorista', 'Origem', 'Destino', 'Peso (kg)', 'Grupo de clientes', 'KM rodado', 'Bruto/km', 'Ações'],
            ['41149 JR TRANSPORTES KM rodado 500,00 km Bruto/km R$ 20,00 Grupo de clientes - Origem - Destino -', 'BDC8D26', '-', '-', '-', '-', '-', '500,00 km', 'R$ 20,00', ''],
          ],
        )

        visit manifest_path(manifest)

        expect(html_table_to_rows(table: find_by_id('manifest_documents'))).to eq(
          [
            ['CT-e', 'Cliente', 'KM rodado', 'Bruto/km'],
            ['74763', '-', '500,00 km', 'R$ 3,96'],
            ['74764', '-', '500,00 km', 'R$ 16,04'],
          ],
        )
      end

      context 'with access to the freight expenses' do
        let!(:freight_expenses_resource) { create(:resource, name: 'Despesas de frete', slug: 'freight_expenses', writable: false) }

        scenario 'adds the freight of the manifest to the net freight of the details' do
          visit manifests_path

          expect(html_table_to_rows.second.last(3)).to eq(['R$ 20,00', 'R$ 20,00', ''])

          visit manifest_path(manifest)

          expect(dl_to_hash('#manifest_net_freight')).to include('Frete bruto' => 'R$ 10.000,00', '(=) Frete líquido' => 'R$ 10.000,00')
          expect(html_table_to_rows(table: find_by_id('manifest_documents'))).to eq(
            [
              ['CT-e', 'Cliente', 'KM rodado', 'Bruto/km', 'Líquido/km'],
              ['74763', '-', '500,00 km', 'R$ 3,96', 'R$ 3,96'],
              ['74764', '-', '500,00 km', 'R$ 16,04', 'R$ 16,04'],
            ],
          )
        end
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
        create(:atua_transport_document, tenant:, number: '74130', series: 1, branch_name: 'JR TRANSPORTES', toll_cents: 20_000,
                                         driver_name: 'JOÃO DA SILVA', taker_name: 'USIMINAS')
      end
      let!(:linked_document) do
        create(:atua_manifest_document, tenant:, manifest_code: 41_236, transport_document_number: '74130', transport_document_series: 1,
                                        branch_name: 'JR TRANSPORTES', recipient_name: 'FIAT', origin_city: 'Ipatinga', origin_state: 'MG',
                                        destination_city: 'Betim', destination_state: 'MG', weight_kg: BigDecimal('19170'), freight_cents: 555_040,
                                        calculated_distance_km: BigDecimal('200'), document_distance_km: BigDecimal('180'))
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
          'MDF-e' => '40772',
          'Placa' => 'RHJ4E07',
          'Motorista' => 'JOÃO DA SILVA',
          'Origem' => 'Ipatinga/MG',
          'Destino' => 'Betim/MG',
          'Peso (kg)' => '19.170,00',
          'KM rodado' => '200,00 km',
          'Bruto/km' => 'R$ 2,78',
        )
        expect(manifest.documents.count).to eq(2)
        expect(html_table_to_rows(table: find_by_id('manifest_documents'))).to eq(
          [
            ['CT-e', 'Cliente', 'KM rodado', 'Bruto/km'],
            ['74130', 'USIMINAS', '200,00 km', 'R$ 2,78'],
            ['74199', '-', '-', '-'],
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
        let!(:expenses_resource) { create(:resource, name: 'Despesas', slug: 'expenses', writable: false) }
        let!(:other_transport_document) do
          create(:atua_transport_document, tenant:, number: '74131', series: 1, branch_code: 2, branch_name: 'JR TRANSPORTES', freight_cents: 300_000,
                                           weight_freight_cents: 260_000, toll_cents: 15_000, icms_cents: 25_000)
        end

        before do
          create(:atua_manifest_document, tenant:, manifest_code: 41_236, transport_document_number: '74131', transport_document_series: 1,
                                          branch_name: 'JR TRANSPORTES')
          create(:atua_toll_voucher, tenant:, transport_document_number: '74131', branch_code: 2, toll_cents: 15_000)
          create(:freight_expense, tenant:, transport_document:, amount_cents: 11_101)
          create(:freight_expense, :insurance, tenant:, transport_document:)
          create(:freight_expense, tenant:, transport_document: other_transport_document, amount_cents: 6_000)
          create(:freight_expense, :tonnage, tenant:, transport_document: other_transport_document)
          create(:atua_expense, tenant:, history_name: 'DESCARGA - CHAPA', payee_name: nil, posted_on: Date.new(2026, 10, 3), total_cents: 35_000,
                                cost_object: other_transport_document)
          outside = create(:atua_transport_document, tenant:, number: '74200', series: 1, branch_name: 'JR TRANSPORTES')
          create(:freight_expense, tenant:, transport_document: outside, amount_cents: 99_999)
        end

        scenario 'shows the net freight of the trip discounting the toll vouchers' do
          visit manifest_path(manifest)

          expect(FreightExpense.count).to eq(5)
          expect(dl_to_hash('#manifest_net_freight')).to eq(
            'Frete bruto' => 'R$ 3.555,04',
            '(−) Comissões' => 'R$ 171,01',
            '(−) Custos por tonelada' => 'R$ 408,53',
            '(−) Seguro nacional da carga' => 'R$ 2,20',
            '(−) Seguro internacional da carga (com IOF)' => 'R$ 0,00',
            '(−) Forro de lona' => 'R$ 0,00',
            '(−) Combustível' => 'R$ 0,00',
            '(−) Despesas do frete na Atua' => 'R$ 350,00',
            '(−) Pedágio' => 'R$ 150,00',
            '(=) Frete líquido' => 'R$ 2.473,30',
          )
        end

        scenario 'shows the loaded km that divides the gross and the net freight of the trip' do
          visit manifest_path(manifest)

          expect(dl_to_hash('#manifest_data')).to include(
            'KM rodado' => '200,00 km',
            'Bruto/km' => 'R$ 17,78',
            'Líquido/km' => 'R$ 12,37',
          )
        end

        scenario 'shows the gross and the net freight per loaded km of each transport document' do
          visit manifest_path(manifest)

          expect(manifest.documents.count).to eq(3)
          expect(html_table_to_rows(table: find_by_id('manifest_documents'))).to eq(
            [
              ['CT-e', 'Cliente', 'KM rodado', 'Bruto/km', 'Líquido/km'],
              ['74130', 'USIMINAS', '200,00 km', 'R$ 2,78', 'R$ 2,21'],
              ['74131', '-', '-', '-', '-'],
              ['74199', '-', '-', '-', '-'],
            ],
          )
        end

        scenario 'unifies the internal expenses, the toll and the Atua expenses of the trip with the total of the net freight deductions' do
          visit manifest_path(manifest)

          expect(FreightExpense.count).to eq(5)
          expect(Atua::TollVoucher.count).to eq(1)
          expect(Atua::Expense.count).to eq(1)
          expect(html_table_to_rows(table: find_by_id('manifest_expenses'))).to eq(
            [
              ['Despesa', 'Tipo', 'CT-e', 'Lançado em', 'Detalhe', 'Valor'],
              ['Comissão', 'Interna', '74130', '-', 'Nacional · R$ 1.000,00 · 2,00%', 'R$ 111,01'],
              ['Seguro da carga', 'Interna', '74130', '-', 'Alíquota de seguro · R$ 10.000,00 · 0,022%', 'R$ 2,20'],
              ['Comissão', 'Interna', '74131', '-', 'Nacional · R$ 1.000,00 · 2,00%', 'R$ 60,00'],
              ['Custo por tonelada', 'Interna', '74131', '-', 'Brasiltec – Cubatão/SP (Cubatão) · 32,500 t · R$ 12,57/t', 'R$ 408,53'],
              ['Pedágio no frete', 'Pedágio', '74131', '-', '-', 'R$ 150,00'],
              ['DESCARGA - CHAPA', 'Atua', '74131', '03/10/2026', '-', 'R$ 350,00'],
            ],
          )
          expect(page).to have_css('#manifest_expenses_total', text: 'Total de despesas R$ 1.081,74')
          expect(page).to have_no_text('Despesas internas da viagem')
        end
      end

      context 'without access to the freight expenses' do
        let!(:freight_expense) { create(:freight_expense, tenant:, transport_document:, amount_cents: 11_101) }

        scenario 'does not show the freight expenses' do
          visit manifest_path(manifest)

          expect(FreightExpense.count).to eq(1)
          expect(page).to have_css('h1.page-title', text: 'Manifesto 40772')
          expect(page).to have_no_css('#manifest_net_freight')
          expect(page).to have_no_css('#manifest_expenses')
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
                ['Despesa', 'Tipo', 'CT-e', 'Lançado em', 'Detalhe', 'Valor'],
                ['PEDAGIO', 'Atua', '74130', '02/10/2026', 'VIA 040', 'R$ 150,00'],
                ['DESCARGA - CHAPA', 'Atua', '74131', '03/10/2026', '-', 'R$ 350,00'],
              ],
            )
            expect(page).to have_css('#manifest_expenses_total', text: 'Total de despesas R$ 500,00')
          end

          scenario 'does not flag expenses of the trip with different documents as duplicates' do
            visit manifest_path(manifest)

            expect(page).to have_css('#manifest_expenses')
            expect(page).to have_no_css('#duplicate_expenses')
            expect(page).to have_no_text('Possível duplicidade')
          end

          context 'when an Atua expense of the trip was posted twice' do
            before do
              unload.update!(payee_code: 8800, payee_name: 'CHAPAS SANTOS', document_number: '5521')
              create(:atua_expense, tenant:, code: 590_403, posted_at: Time.zone.local(2026, 10, 3, 16), posted_on: Date.new(2026, 10, 3),
                                    history_name: 'DESCARGA - CHAPA', payee_code: 8800, payee_name: 'CHAPAS SANTOS', document_number: '5521',
                                    total_cents: 35_000, cost_object: transport_document)
            end

            scenario 'flags both postings as a possible duplicate above the expenses' do
              visit manifest_path(manifest)

              expect(Atua::Expense.count).to eq(6)
              expect(page).to have_css('#duplicate_expenses', text: '1 despesa da Atua parece lançada em duplicidade')
              expect(html_table_to_rows(table: find_by_id('manifest_expenses'))).to eq(
                [
                  ['Despesa', 'Tipo', 'CT-e', 'Lançado em', 'Detalhe', 'Valor'],
                  ['DESCARGA - CHAPA Possível duplicidade', 'Atua', '74130', '03/10/2026', 'CHAPAS SANTOS', 'R$ 350,00'],
                  ['PEDAGIO', 'Atua', '74130', '02/10/2026', 'VIA 040', 'R$ 150,00'],
                  ['DESCARGA - CHAPA Possível duplicidade', 'Atua', '74131', '03/10/2026', 'CHAPAS SANTOS', 'R$ 350,00'],
                ],
              )
              expect(page).to have_css('#manifest_expenses tr.table-warning', count: 2)
            end
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

        context 'when a value complement pays back the unloading of a transport document of the trip' do
          let!(:unload) do
            create(:atua_expense, tenant:, code: 590_402, posted_at: Time.zone.local(2026, 10, 3, 15), posted_on: Date.new(2026, 10, 3),
                                  history_code: 72, history_name: 'CHAPA / CARGA, DESCARGA', payee_name: nil, total_cents: 73_600,
                                  cost_object: transport_document)
          end
          let!(:complement) do
            create(:atua_transport_document, tenant:, number: '74150', series: 1, branch_name: 'JR TRANSPORTES',
                                             issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT, complemented_transport_document: transport_document,
                                             freight_cents: 73_600, issued_at: Time.zone.local(2026, 10, 4, 9))
          end

          scenario 'credits the complement in green against the expenses of the trip' do
            visit manifest_path(manifest)

            expect(Atua::TransportDocument.count).to eq(2)
            expect(html_table_to_rows(table: find_by_id('manifest_expenses'))).to eq(
              [
                ['Despesa', 'Tipo', 'CT-e', 'Lançado em', 'Detalhe', 'Valor'],
                ['CHAPA / CARGA, DESCARGA', 'Atua', '74130', '03/10/2026', '-', 'R$ 736,00'],
                ['Complemento de valores — CT-e 74150', 'Crédito de complemento', '74130', '04/10/2026', '-', '-R$ 736,00'],
              ],
            )
            expect(page).to have_css("#complement_credit_atua_transport_document_#{complement.id} .text-success", text: '-R$ 736,00')
            expect(page).to have_css('#manifest_expenses_total', text: 'Total de despesas R$ 0,00')
          end
        end
      end
    end

    context 'when the manifest has an empty leg from the previous trip of the truck' do
      let!(:previous_manifest) { create(:atua_manifest, :with_transport_document, tenant:, code: 41_100, number: '40700', plate: 'RHJ4E07') }
      let!(:manifest) { create(:atua_manifest, :with_transport_document, tenant:, code: 41_200, number: '40772', plate: 'RHJ4E07') }
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
          'De' => 'RUA DAS FLORES 10 - BETIM/MG',
          'Para' => 'CONTAGEM/MG',
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
            'De' => 'RUA DAS FLORES 10 - BETIM/MG',
            'Para' => '-',
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
    let!(:manifest) { create(:atua_manifest, :with_transport_document, tenant:, number: '40772') }

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

      scenario 'loads the customers of the filters without access to the transport documents' do
        create(:atua_customer, tenant:, code: 7100, name: 'USIMINAS IPATINGA')

        visit customer_options_manifests_path

        expect(page).to have_css('#customer_code_select [role="option"]', text: 'USIMINAS IPATINGA', visible: :all)
      end

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

    context 'when the manifest is listed' do
      let!(:freight_expenses_resource) { create(:resource, name: 'Despesas de frete', slug: 'freight_expenses', writable: false) }

      before do
        transport_document = create(:atua_transport_document, tenant:, number: '74140', series: 1, branch_name: manifest.branch_name,
                                                              freight_cents: 1_000_000, taker_name: 'USIMINAS IPATINGA')
        create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: '74140', transport_document_series: 1,
                                        branch_name: manifest.branch_name, calculated_distance_km: 500, origin_city: 'IPATINGA',
                                        origin_state: 'MG', destination_city: 'SANTOS', destination_state: 'SP')
        create(:freight_expense, tenant:, transport_document:, amount_cents: 100_000)
      end

      scenario 'stacks the per km, the customer and the route under the number without horizontal scroll' do
        visit manifests_path

        expect(page).to have_css('th', text: /\AMDF-e\z/i)
        expect(page).to have_no_css('th', text: %r{\ABruto/km\z}i)
        expect(page).to have_no_css('th', text: /\ACliente\z/i)
        details = find('.manifest-mobile-details')
        expect(details.all('dt').map(&:text).zip(details.all('dd').map(&:text))).to eq(
          [['KM rodado', '500,00 km'], ['Bruto/km', 'R$ 20,00'], ['Líquido/km', 'R$ 18,00'], ['Grupo de clientes', 'USIMINAS IPATINGA'], ['Origem', 'IPATINGA/MG'],
           ['Destino', 'SANTOS/SP']],
        )
        expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      end
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
        expect(page).to have_no_css('#manifest_expenses th', text: 'Detalhe')
        expect(page).to have_no_css('#manifest_expenses th', text: 'CT-e')
        expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      end
    end

    context 'when the manifest has a transport document with toll' do
      let!(:transport_documents_resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }

      before do
        create(:atua_transport_document, tenant:, number: '74130', series: 1, branch_name: manifest.branch_name, freight_cents: 100_000,
                                         weight_freight_cents: 90_000, toll_cents: 10_000, taker_name: 'USIMINAS')
        create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: '74130',
                                        transport_document_series: 1, branch_name: manifest.branch_name, freight_cents: 100_000,
                                        document_distance_km: BigDecimal('100'))
      end

      scenario 'hides the customer column of the transport documents without horizontal scroll' do
        visit manifest_path(manifest)

        expect(page).to have_css('#manifest_documents td', text: 'R$ 10,00')
        expect(page).to have_no_css('#manifest_documents th', text: 'Cliente')
        expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      end
    end

    context 'when the manifest is linked to a transport document' do
      before do
        create(:atua_transport_document, tenant:, number: '74130', series: 1, branch_name: manifest.branch_name)
        create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: '74130',
                                        transport_document_series: 1, branch_name: manifest.branch_name)
      end

      scenario 'keeps only the essential columns without horizontal scroll' do
        visit manifests_path

        expect(page).to have_link('40772')
        expect(page).to have_no_css('th', text: 'Placa')
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
      visit manifests_path
      find(:link, href: '#filtersModal').click

      within('#filtersModal') { expect(page).to have_field('Emitidos até') }
      start_top = page.evaluate_script("document.getElementById('start_date').getBoundingClientRect().top")
      end_top = page.evaluate_script("document.getElementById('end_date').getBoundingClientRect().top")
      expect(end_top).to be > start_top
    end
  end
end
