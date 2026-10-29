require 'rails_helper'

describe 'Excluded issuers' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Emissores desconsiderados', slug: 'excluded_issuers') }

  context 'without a signed in user' do
    scenario 'redirects the listing to the login screen' do
      visit excluded_issuers_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'does not exclude an issuer' do
      expect do
        page.driver.submit :post, excluded_issuers_path, { excluded_issuer: { code: '6190' } }
      end.not_to change(ExcludedIssuer, :count)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when no issuer is excluded' do
      scenario 'shows the empty state message' do
        visit excluded_issuers_path

        expect(ExcludedIssuer.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are excluded issuers' do
      let!(:maycon) { create(:excluded_issuer, tenant:, code: 6190, name: 'MAYCON DORALINO SANTOS LORENA') }
      let!(:jefferson) { create(:excluded_issuer, tenant:, code: 1951, name: 'JEFFERSON ANDRE REMONATTO') }
      let!(:stranger) { create(:excluded_issuer, tenant: other_tenant, code: 9166, name: 'EMISSOR DE OUTRA') }

      before do
        create(:atua_transport_document, tenant:, document_kind: 'ce', issuer_code: 6190, freight_cents: 1_657_920)
        create(:atua_transport_document, tenant:, document_kind: 'ce', issuer_code: 6190, freight_cents: 1_547_680)
        create(:atua_transport_document, tenant:, document_kind: 'ce', issuer_code: 1951, freight_cents: 1_464_340)
      end

      scenario 'lists the issuers of the tenant from the registrations menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Emissores desconsiderados'
        end

        expect(page).to have_current_path(excluded_issuers_path)
        expect(ExcludedIssuer.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Emissor', 'Código no Atua', 'Documentos', 'Frete bruto', 'Ações'],
            ['JEFFERSON ANDRE REMONATTO', '1951', '1', 'R$ 14.643,40', ''],
            ['MAYCON DORALINO SANTOS LORENA', '6190', '2', 'R$ 32.056,00', ''],
          ],
        )
        expect(page).to have_link('Voltar a considerar', href: excluded_issuer_path(maycon))
        expect(page).to have_link('Voltar a considerar', href: excluded_issuer_path(jefferson))
        expect(page).to have_link('Desconsiderar Emissor', href: new_excluded_issuer_path)
        expect(page).to have_no_text('EMISSOR DE OUTRA')
      end

      scenario 'filters the issuers by name' do
        visit excluded_issuers_path
        fill_in 'Nome do emissor', with: 'lorena'
        click_on 'Aplicar Filtros'

        expect(ExcludedIssuer.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Emissor', 'Código no Atua', 'Documentos', 'Frete bruto', 'Ações'],
            ['MAYCON DORALINO SANTOS LORENA', '6190', '2', 'R$ 32.056,00', ''],
          ],
        )
      end

      scenario 'asks for confirmation and considers the issuer again' do
        visit excluded_issuers_path

        expect(page).to have_css(
          "#excluded_issuer_#{maycon.id} a[data-turbo-confirm='Os documentos deste emissor voltarão a entrar no faturamento de " \
          "fretes. Deseja continuar?']",
        )

        expect { page.driver.submit :delete, excluded_issuer_path(maycon), {} }.to change(ExcludedIssuer, :count).by(-1)

        expect(page).to have_current_path(excluded_issuers_path)
        expect(page).to have_text('Os documentos do emissor voltaram a ser considerados.')
        expect(ExcludedIssuer.where(tenant:).pluck(:code)).to eq([1951])
      end

      scenario 'does not remove an issuer of another tenant' do
        expect { page.driver.submit :delete, excluded_issuer_path(stranger), {} }.not_to change(ExcludedIssuer, :count)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when excluding an issuer' do
      before do
        create(:atua_transport_document, tenant:, issuer_code: 6001, issuer_name: 'EMISSAO CTE')
        create(:atua_transport_document, tenant:, document_kind: 'ce', issuer_code: 6190, issuer_name: 'MAYCON DORALINO SANTOS LORENA',
                                         freight_cents: 1_657_920)
        create(:atua_transport_document, tenant: other_tenant, issuer_code: 9166, issuer_name: 'MARLEI JULIA OLIVEIRA DA SILVA')
      end

      scenario 'chooses one of the issuers of the tenant and lists it' do
        visit excluded_issuers_path
        click_on 'Desconsiderar Emissor'

        expect(page).to have_select('Emissor', options: ['', 'EMISSAO CTE (6001)', 'MAYCON DORALINO SANTOS LORENA (6190)'])

        select 'MAYCON DORALINO SANTOS LORENA (6190)', from: 'Emissor'

        expect { click_on 'Desconsiderar Emissor' }.to change(ExcludedIssuer, :count).by(1)

        excluded_issuer = ExcludedIssuer.last
        expect(page).to have_current_path(excluded_issuers_path)
        expect(page).to have_text('Emissor desconsiderado com sucesso.')
        expect(excluded_issuer).to have_attributes(tenant:, code: 6190, name: 'MAYCON DORALINO SANTOS LORENA')
        expect(html_table_to_rows).to eq(
          [
            ['Emissor', 'Código no Atua', 'Documentos', 'Frete bruto', 'Ações'],
            ['MAYCON DORALINO SANTOS LORENA', '6190', '1', 'R$ 16.579,20', ''],
          ],
        )

        click_on 'Desconsiderar Emissor'

        expect(page).to have_select('Emissor', options: ['', 'EMISSAO CTE (6001)'])
      end

      scenario 'shows the error of the required issuer' do
        visit new_excluded_issuer_path

        expect { click_on 'Desconsiderar Emissor' }.not_to change(ExcludedIssuer, :count)

        expect(page).to have_text('Emissor não pode ficar em branco')
      end

      scenario 'rejects an issuer of another tenant through a forged request' do
        expect do
          page.driver.submit :post, excluded_issuers_path, { excluded_issuer: { code: '9166' } }
        end.not_to change(ExcludedIssuer, :count)

        expect(page.status_code).to eq(422)
        expect(page).to have_text('Emissor não emitiu nenhum CT-e ou CE')
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:excluded_issuer) { create(:excluded_issuer, tenant:, code: 6190, name: 'MAYCON DORALINO SANTOS LORENA') }

    before { login_as(operator, scope: :user) }

    context 'without access to the excluded issuers' do
      scenario 'is sent back with an access denied message' do
        visit excluded_issuers_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the excluded issuers' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'lists the issuers without the management actions' do
        visit excluded_issuers_path

        expect(ExcludedIssuer.count).to eq(1)
        expect(html_table_to_rows).to eq(
          [
            ['Emissor', 'Código no Atua', 'Documentos', 'Frete bruto', 'Ações'],
            ['MAYCON DORALINO SANTOS LORENA', '6190', '0', 'R$ 0,00', ''],
          ],
        )
        expect(page).to have_no_link('Desconsiderar Emissor')
        expect(page).to have_no_link('Voltar a considerar')
      end

      scenario 'cannot consider an issuer again through a forged request' do
        expect { page.driver.submit :delete, excluded_issuer_path(excluded_issuer), {} }.not_to change(ExcludedIssuer, :count)

        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:excluded_issuer) { create(:excluded_issuer, tenant:, code: 6190, name: 'MAYCON DORALINO SANTOS LORENA') }

    before { login_as(admin, scope: :user) }

    scenario 'keeps the essential columns and the action without scrolling sideways' do
      visit excluded_issuers_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'EMISSOR')
      expect(page).to have_no_css('th', text: 'CÓDIGO NO ATUA')
      expect(page).to have_no_css('th', text: 'FRETE BRUTO')

      within("#excluded_issuer_#{excluded_issuer.id}") do
        expect(page).to have_link('Voltar a considerar', href: excluded_issuer_path(excluded_issuer))
      end

      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
