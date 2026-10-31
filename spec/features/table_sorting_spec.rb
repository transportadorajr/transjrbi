require 'rails_helper'

describe 'Table sorting' do
  let!(:tenant) { create(:tenant) }
  let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

  def first_column
    html_table_to_rows.drop(1).map(&:first)
  end

  def column(label)
    rows = html_table_to_rows

    rows.drop(1).pluck(rows.first.index(label))
  end

  before { login_as(admin, scope: :user) }

  context 'when listing the macro regions' do
    let!(:resource) { create(:resource, name: 'Macrorregiões', slug: 'macro_regions') }
    let!(:santos) { create(:macro_region, tenant:, name: 'Santos', state: 'SP') }
    let!(:agua) { create(:macro_region, tenant:, name: 'Água Branca', state: 'SP') }
    let!(:betim) { create(:macro_region, tenant:, name: 'Betim', state: 'MG') }

    scenario 'keeps the default order until a header is clicked' do
      visit macro_regions_path

      expect(MacroRegion.count).to eq(3)
      expect(first_column).to eq(['Betim', 'Água Branca', 'Santos'])
      expect(page).to have_no_css('th[aria-sort]')
    end

    scenario 'toggles between ascending and descending when the header is clicked' do
      visit macro_regions_path

      click_on 'Nome'
      expect(first_column).to eq(['Água Branca', 'Betim', 'Santos'])
      expect(page).to have_css('th[aria-sort="ascending"]', text: 'Nome')

      click_on 'Nome'
      expect(first_column).to eq(['Santos', 'Betim', 'Água Branca'])
      expect(page).to have_css('th[aria-sort="descending"]', text: 'Nome')

      click_on 'Nome'
      expect(first_column).to eq(['Água Branca', 'Betim', 'Santos'])
    end

    scenario 'ignores a column that was not whitelisted' do
      visit macro_regions_path(sort: 'state; DROP TABLE users', direction: 'desc')

      expect(page.status_code).to eq(200)
      expect(first_column).to eq(['Betim', 'Água Branca', 'Santos'])
    end

    scenario 'keeps the sort when a filter is applied' do
      visit macro_regions_path(sort: 'name', direction: 'desc')
      fill_in 'name', with: 'a'
      click_on 'Aplicar Filtros'

      expect(page).to have_current_path(/direction=desc/)
      expect(page).to have_current_path(/sort=name/)
      expect(first_column).to eq(['Santos', 'Água Branca'])
    end

    scenario 'drops the sort when the filters are cleared' do
      visit macro_regions_path(sort: 'name', direction: 'desc')
      click_on 'Limpar Filtros'

      expect(first_column).to eq(['Betim', 'Água Branca', 'Santos'])
    end

    context 'with more than one page' do
      before do
        allow(Kaminari.config).to receive(:default_per_page).and_return(2)
      end

      scenario 'keeps the sort across the pages and goes back to the first page when sorting' do
        visit macro_regions_path(sort: 'name', direction: 'desc')
        expect(first_column).to eq(%w[Santos Betim])

        within('.table-pagination') { click_on '2' }
        expect(first_column).to eq(['Água Branca'])

        click_on 'Nome'
        expect(page).to have_no_current_path(/page=/)
        expect(first_column).to eq(['Água Branca', 'Betim'])
      end
    end
  end

  context 'when listing the screens sorted by name' do
    let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }

    context 'with customers' do
      let!(:resource) { create(:resource, name: 'Clientes', slug: 'customers', writable: false) }

      before do
        create(:atua_customer, tenant:, name: 'ZETA')
        create(:atua_customer, tenant:, name: 'ALFA')
      end

      scenario 'sorts by name' do
        visit customers_path(sort: 'name', direction: 'desc')

        expect(Atua::Customer.count).to eq(2)
        expect(first_column.map { |cell| cell.split.first }).to eq(%w[ZETA ALFA])
        expect(page).to have_css('th[aria-sort="descending"]', text: 'Nome')
      end
    end

    context 'with users' do
      let!(:resource) { create(:resource, name: 'Usuários', slug: 'users') }

      before { create(:user, tenant:, name: 'Zélia Operadora') }

      scenario 'sorts by name' do
        visit users_path(sort: 'name', direction: 'desc')

        expect(User.where(tenant:).count).to eq(2)
        expect(first_column.first).to include('Zélia Operadora')
        expect(first_column.last).to include('Bruna Admin')
      end
    end

    context 'with vehicles' do
      let!(:resource) { create(:resource, name: 'Veículos', slug: 'vehicles', writable: false) }

      before do
        create(:atua_vehicle, tenant:, plate: 'AAA1A11', driver_code: 1, driver_name: 'ZECA')
        create(:atua_vehicle, tenant:, plate: 'BBB2B22', driver_code: 2, driver_name: 'ANA')
      end

      scenario 'sorts by plate and by driver' do
        visit vehicles_path(sort: 'plate', direction: 'desc')
        expect(column('Motorista')).to eq(%w[ANA ZECA])

        within('thead') { click_on 'Motorista' }
        expect(column('Motorista')).to eq(%w[ANA ZECA])
        within('thead') { click_on 'Motorista' }
        expect(column('Motorista')).to eq(%w[ZECA ANA])
      end
    end

    context 'with drivers' do
      let!(:resource) { create(:resource, name: 'Motoristas', slug: 'drivers', writable: false) }

      before do
        create(:atua_vehicle, tenant:, plate: 'AAA1A11', driver_code: 1, driver_name: 'ZECA')
        create(:atua_vehicle, tenant:, plate: 'BBB2B22', driver_code: 2, driver_name: 'ANA')
      end

      scenario 'sorts by name without a primary key on the grouped relation' do
        visit drivers_path(sort: 'driver_name', direction: 'desc')

        expect(first_column.map { |cell| cell.split.first }).to eq(%w[ZECA ANA])
      end
    end

    context 'with freight expenses' do
      let!(:resource) { create(:resource, name: 'Despesas de frete', slug: 'freight_expenses', writable: false) }

      before do
        create(:freight_expense, tenant:, transport_document: create(:atua_transport_document, tenant:, taker_name: 'ZETA'))
        create(:freight_expense, tenant:, transport_document: create(:atua_transport_document, tenant:, taker_name: 'ALFA'))
      end

      scenario 'sorts by the taker of the transport document' do
        visit freight_expenses_path(sort: 'customer_name')

        expect(FreightExpense.count).to eq(2)
        expect(column('Tomador')).to eq(%w[ALFA ZETA])
      end
    end
  end

  context 'when listing the transport documents' do
    let!(:resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }
    let!(:cheap) do
      create(:atua_transport_document, tenant:, number: '1001', taker_name: 'BETA', driver_name: 'ZECA', freight_cents: 100_000, weight_freight_cents: 100_000,
                                       toll_cents: 0, icms_cents: 0, ad_valorem_cents: 0, other_charges_cents: 0)
    end
    let!(:dear) do
      create(:atua_transport_document, tenant:, number: '1002', taker_name: 'ÁGUA', driver_name: 'ANA', freight_cents: 300_000, weight_freight_cents: 300_000,
                                       toll_cents: 0, icms_cents: 0, ad_valorem_cents: 0, other_charges_cents: 0)
    end
    let!(:canceled) do
      create(:atua_transport_document, tenant:, number: '1003', taker_name: 'CARLOS', driver_name: 'MARIA', freight_cents: 900_000, canceled_at: Time.current)
    end

    before { create(:freight_expense, tenant:, transport_document: dear, amount_cents: 250_000) }

    def numbers
      first_column.map { |cell| cell.split.first }
    end

    context 'with access to the freight expenses' do
      let!(:freight_expenses_resource) { create(:resource, name: 'Despesas de frete', slug: 'freight_expenses', writable: false) }

      scenario 'shows the net freight and matches the net freight of the document' do
        visit transport_documents_path(sort: 'net', direction: 'desc')

        expect(Atua::TransportDocument.count).to eq(3)
        expect(numbers).to eq(%w[1001 1002 1003])
        expect(column('Frete líquido')).to eq(['R$ 1.000,00', 'R$ 500,00', '-'])
        expect(NetFreight.for(Atua::TransportDocument.where(id: dear.id)).net).to eq(Money.from_cents(50_000))
      end

      scenario 'keeps a canceled document last in both directions of the net freight' do
        visit transport_documents_path(sort: 'net', direction: 'asc')

        expect(numbers).to eq(%w[1002 1001 1003])
      end

      scenario 'starts the net freight sort from the highest value' do
        visit transport_documents_path
        within('thead') { click_on 'Frete líquido' }

        expect(numbers).to eq(%w[1001 1002 1003])
      end
    end

    context 'without access to the freight expenses' do
      scenario 'hides the net freight and ignores its sort' do
        visit transport_documents_path(sort: 'net', direction: 'asc')

        expect(numbers).to eq(%w[1003 1002 1001])
        expect(page).to have_no_css('th', text: 'Frete líquido')
      end
    end

    scenario 'sorts by customer, driver and gross freight' do
      visit transport_documents_path

      within('thead') { click_on 'Cliente' }
      expect(column('Cliente')).to eq(%w[ÁGUA BETA CARLOS])

      within('thead') { click_on 'Motorista' }
      expect(column('Motorista')).to eq(%w[ANA MARIA ZECA])

      within('thead') { click_on 'Frete bruto' }
      expect(numbers).to eq(%w[1003 1002 1001])
    end
  end

  context 'when listing the manifests' do
    let!(:resource) { create(:resource, name: 'Manifestos', slug: 'manifests', writable: false) }
    let!(:large) { create(:atua_manifest, tenant:, code: 1, number: '501', branch_name: 'JR') }
    let!(:small) { create(:atua_manifest, tenant:, code: 2, number: '502', branch_name: 'JR') }
    let!(:empty) { create(:atua_manifest, tenant:, code: 3, number: '503', branch_name: 'JR') }

    def add_document(manifest, number, **attributes)
      document = create(:atua_transport_document, tenant:, number:, series: 1, branch_name: 'JR', toll_cents: 0, **attributes)
      create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: number,
                                      transport_document_series: 1, branch_name: 'JR')
      document
    end

    def numbers
      first_column.map { |cell| cell.split.first }
    end

    before do
      add_document(large, '9001', taker_name: 'MENOR', driver_name: 'AUXILIAR', freight_cents: 100_000)
      add_document(large, '9002', taker_name: 'ZETA', driver_name: 'ANA', freight_cents: 500_000)
      add_document(small, '9003', taker_name: 'ÁGUA', driver_name: 'ZECA', freight_cents: 200_000)
      add_document(small, '9004', taker_name: 'MAIOR CANCELADO', driver_name: 'OUTRO', freight_cents: 900_000, canceled_at: Time.current)
    end

    scenario 'sorts by the total freight of the valid transport documents' do
      visit manifests_path(sort: 'gross', direction: 'desc')

      expect(Atua::Manifest.count).to eq(3)
      expect(numbers).to eq(%w[501 502 503])
      expect(column('Valor total do frete')).to eq(['R$ 6.000,00', 'R$ 2.000,00', 'R$ 0,00'])
    end

    scenario 'ignores the columns that left the listing' do
      visit manifests_path(sort: 'net', direction: 'desc')

      expect(numbers).to match_array(%w[501 502 503])
      expect(page).to have_no_css('th', text: 'Frete líquido')
    end
  end

  context 'on a phone', :js do
    let!(:resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }

    before do
      create(:atua_transport_document, tenant:, number: '1001', freight_cents: 100_000)
      create(:atua_transport_document, tenant:, number: '1002', freight_cents: 300_000)
      use_mobile_screen
    end

    scenario 'sorts by a column hidden on the phone through the sort menu without horizontal scroll' do
      visit transport_documents_path
      click_on 'Ordenar por'
      within('.table-card-header') { click_on 'Frete bruto' }

      expect(page).to have_current_path(/sort=gross/)
      expect(first('tbody tr td a').text).to eq('1002')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
