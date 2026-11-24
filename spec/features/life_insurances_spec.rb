require 'rails_helper'

describe 'Life insurances', :hr do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:hr_resource) { create(:resource, name: 'Módulo de RH', slug: 'hr', writable: false) }
  let!(:resource) { create(:resource, name: 'Seguro de vida', slug: 'life_insurances') }
  let!(:mme_policy) { create(:life_insurance_policy, tenant:, company_type: 'mme', capital_cents: 11_500_000) }
  let!(:mm_policy) { create(:life_insurance_policy, tenant:, company_type: 'mm_espinola', capital_cents: 11_000_000) }
  let!(:jose) { create(:employee, tenant:, name: 'JOSE SILVA', legal_id: '52998224725', company_type: 'mme') }
  let!(:ana) { create(:employee, tenant:, name: 'ANA PAULA', legal_id: '11144477735', company_type: 'mm_espinola') }
  let!(:carlos) { create(:employee, tenant:, name: 'CARLOS LIMA', legal_id: '39053344705', company_type: 'mm_espinola') }

  around { |example| travel_to(Time.zone.local(2026, 11, 24, 10)) { example.run } }

  context 'without a signed in user', flipper: :hr do
    scenario 'redirects the listing to the login screen' do
      visit life_insurances_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are insured employees' do
      let!(:jose_insurance) { create(:life_insurance, employee: jose, life_insurance_policy: mme_policy) }
      let!(:ana_insurance) do
        create(:life_insurance, employee: ana, life_insurance_policy: mm_policy, capital_cents: 17_000_000, included_on: Date.new(2026, 3, 1))
      end

      before do
        create(:life_insurance, employee: carlos, life_insurance_policy: mm_policy, excluded_on: Date.new(2026, 11, 1))
        create(:life_insurance, employee: create(:employee, tenant:, name: 'PEDRO NOVO', legal_id: '86288366757', company_type: 'mme'),
                                life_insurance_policy: mme_policy, included_on: Date.new(2026, 12, 1))
        create(:life_insurance, employee: create(:employee, tenant: other_tenant, name: 'FUNCIONÁRIO DE OUTRA'))
      end

      scenario 'lists the coverages of the insured employees from the HR menu' do
        visit life_insurances_path
        within('.sidebar-desktop') { click_on 'Seguro de vida' }

        expect(page).to have_current_path(life_insurances_path)
        expect(LifeInsurance.count).to eq(5)
        expect(html_table_to_rows).to eq(
          [
            ['Funcionário', 'Empresa', 'Capital segurado', 'Morte do cônjuge', 'Morte de filhos', 'Assistência funeral familiar', 'Prêmio'],
            ['ANA PAULA', 'MM Espinola', 'R$ 170.000,00', 'R$ 85.000,00', 'R$ 17.000,00', 'R$ 6.000,00', 'R$ 54,15'],
            ['JOSE SILVA', 'MME', 'R$ 115.000,00', 'R$ 57.500,00', 'R$ 11.500,00', 'R$ 6.000,00', 'R$ 36,63'],
          ],
        )
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(
          ['Segurados 2', 'Prêmio mensal R$ 90,78', 'Prêmio MME (1) R$ 36,63', 'Prêmio MM Espinola (1) R$ 54,15'],
        )
        expect(page).to have_no_text('CARLOS LIMA')
        expect(page).to have_no_text('PEDRO NOVO')
        expect(page).to have_no_text('FUNCIONÁRIO DE OUTRA')
      end

      scenario 'filters the insured employees by name and company' do
        visit life_insurances_path(name: 'jose')

        expect(LifeInsurance.count).to eq(5)
        expect(html_table_to_rows.drop(1).map(&:first)).to eq(['JOSE SILVA'])

        visit life_insurances_path(company_type: 'mm_espinola')

        expect(html_table_to_rows.drop(1).map(&:first)).to eq(['ANA PAULA'])
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(
          ['Segurados 1', 'Prêmio mensal R$ 54,15', 'Prêmio MM Espinola (1) R$ 54,15'],
        )
      end

      scenario 'sorts the insured employees by premium' do
        visit life_insurances_path(sort: 'premium', direction: 'asc')

        expect(LifeInsurance.count).to eq(5)
        expect(html_table_to_rows.drop(1).map { |row| [row.first, row.last] }).to eq([['JOSE SILVA', 'R$ 36,63'], ['ANA PAULA', 'R$ 54,15']])
      end

      scenario 'exports the insured employees to PDF' do
        visit life_insurances_path(format: :pdf)

        text = PDF::Inspector::Text.analyze(page.body).strings.join
        expect(page.response_headers['Content-Type']).to include('application/pdf')
        expect(LifeInsurance.count).to eq(5)
        expect(text).to include('Relatório do Seguro de Vida', 'ANA PAULA', 'JOSE SILVA', 'R$ 85.000,00', 'R$ 36,63', 'R$ 90,78')
        expect(text).not_to include('CARLOS LIMA', 'FUNCIONÁRIO DE OUTRA')
      end

      scenario 'exports the insured employees to Excel', :xlsx_service, flipper: { hr: :tenant, xlsx_export: :tenant } do
        visit life_insurances_path(company_type: 'mm_espinola')
        click_on 'Exportar Excel'

        expect(page.response_headers['Content-Disposition']).to include('attachment', "seguro-de-vida-#{Date.current.iso8601}.xlsx")
        expect(downloaded_xlsx_rows).to eq(
          [
            ['Funcionário', 'Empresa', 'Capital segurado', 'Morte acidental', 'Invalidez permanente por acidente', 'Invalidez funcional por doença',
             'Morte do cônjuge', 'Morte de filhos', 'Assistência funeral familiar', 'Prêmio', 'Inclusão'],
            ['ANA PAULA', 'MM Espinola', 170_000, 170_000, 170_000, 170_000, 85_000, 17_000, 6000, 54.15, Date.new(2026, 3, 1)],
          ],
        )
      end
    end

    context 'when there are no insured employees' do
      scenario 'shows the empty listing' do
        visit life_insurances_path

        expect(LifeInsurance.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Segurados 0', 'Prêmio mensal R$ 0,00'])
      end
    end
  end

  context 'when the owner is signed in on a phone', :js, flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before do
      create(:life_insurance, employee: jose, life_insurance_policy: mme_policy)
      create(:life_insurance, employee: ana, life_insurance_policy: mm_policy, capital_cents: 17_000_000)
      login_as(owner, scope: :user)
    end

    scenario 'keeps the employee and the premium and sorts by capital from the menu' do
      visit life_insurances_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'FUNCIONÁRIO')
      expect(page).to have_css('th', text: 'PRÊMIO')
      expect(page).to have_no_css('th', text: 'CAPITAL SEGURADO')
      expect(page).to have_no_css('th', text: 'MORTE DO CÔNJUGE')

      click_on 'Ordenar por'
      within('.table-card-header') { click_on 'Capital segurado' }

      expect(page).to have_current_path(life_insurances_path(sort: :capital, direction: :desc))
      expect(all('tbody tr td:first-child').map(&:text)).to eq(['ANA PAULA', 'JOSE SILVA'])
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
