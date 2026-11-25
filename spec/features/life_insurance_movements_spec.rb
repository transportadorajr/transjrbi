require 'rails_helper'

describe 'Life insurance movements', :hr do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:hr_resource) { create(:resource, name: 'Módulo de RH', slug: 'hr', writable: false) }
  let!(:resource) { create(:resource, name: 'Seguro de vida', slug: 'life_insurances') }
  let!(:mme_policy) { create(:life_insurance_policy, tenant:, company_type: 'mme', capital_cents: 11_500_000) }
  let!(:mm_policy) { create(:life_insurance_policy, tenant:, company_type: 'mm_espinola', capital_cents: 11_000_000) }
  let!(:jose) do
    create(:employee, tenant:, name: 'JOSE SILVA', legal_id: '04721755996', company_type: 'mme', born_on: Date.new(1984, 11, 21))
  end
  let!(:ana) do
    create(:employee, tenant:, name: 'ANA PAULA', legal_id: '11144477735', company_type: 'mm_espinola', gender_type: 'female',
                      born_on: Date.new(1998, 3, 15))
  end
  let!(:carlos) do
    create(:employee, tenant:, name: 'CARLOS LIMA', legal_id: '39053344705', company_type: 'mm_espinola', born_on: Date.new(1976, 12, 30))
  end

  around { |example| travel_to(Time.zone.local(2026, 11, 24, 10)) { example.run } }

  before do
    create(:life_insurance, employee: jose, life_insurance_policy: mme_policy, included_on: Date.new(2026, 11, 20))
    create(:life_insurance, employee: ana, life_insurance_policy: mm_policy, included_on: Date.new(2026, 2, 1), excluded_on: Date.new(2026, 11, 10))
    create(:life_insurance, employee: carlos, life_insurance_policy: mm_policy, capital_cents: 17_000_000, capital_changed_on: Date.new(2026, 11, 3))
    create(:life_insurance, employee: create(:employee, tenant:, name: 'PEDRO OUTUBRO', legal_id: '86288366757', company_type: 'mme'),
                            life_insurance_policy: mme_policy, included_on: Date.new(2026, 10, 15))
    create(:life_insurance, employee: create(:employee, tenant: other_tenant, name: 'FUNCIONÁRIO DE OUTRA'), included_on: Date.new(2026, 11, 2))
  end

  context 'without a signed in user', flipper: :hr do
    scenario 'redirects the listing to the login screen' do
      visit life_insurance_movements_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'lists the movements of the current month from the HR menu' do
      visit life_insurances_path
      within('.sidebar-desktop') do
        click_on 'Seguros'
        click_on 'Movimentos do seguro'
      end

      expect(page).to have_current_path(life_insurance_movements_path)
      expect(LifeInsurance.count).to eq(5)
      expect(page).to have_css('.table-card-title', text: 'novembro de 2026')
      expect(html_table_to_rows).to eq(
        [
          ['Funcionário', 'Empresa', 'Movimento', 'Data', 'Capital segurado', 'Prêmio'],
          ['ANA PAULA', 'MM Espinola', 'Exclusão', '10/11/2026', 'R$ 110.000,00', 'R$ 35,04'],
          ['CARLOS LIMA', 'MM Espinola', 'Alteração', '03/11/2026', 'R$ 170.000,00', 'R$ 54,15'],
          ['JOSE SILVA', 'MME', 'Inclusão', '20/11/2026', 'R$ 115.000,00', 'R$ 36,63'],
        ],
      )
      expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Inclusões 1', 'Exclusões 1', 'Alterações 1'])
      expect(page).to have_no_text('FUNCIONÁRIO DE OUTRA')
    end

    scenario 'moves to the previous month keeping the filters' do
      visit life_insurance_movements_path(company_type: 'mme')
      click_on 'Mês anterior'

      expect(page).to have_current_path(life_insurance_movements_path(company_type: 'mme', month: '2026-10'))
      expect(LifeInsurance.count).to eq(5)
      expect(html_table_to_rows.drop(1)).to eq([['PEDRO OUTUBRO', 'MME', 'Inclusão', '15/10/2026', 'R$ 115.000,00', 'R$ 36,63']])
    end

    scenario 'filters the movements by employee and company' do
      visit life_insurance_movements_path(name: 'carlos')

      expect(LifeInsurance.count).to eq(5)
      expect(html_table_to_rows.drop(1).map(&:first)).to eq(['CARLOS LIMA'])

      visit life_insurance_movements_path(company_type: 'mme')

      expect(html_table_to_rows.drop(1).map(&:first)).to eq(['JOSE SILVA'])
    end

    scenario 'shows the empty listing of a month without movements' do
      visit life_insurance_movements_path(month: '2026-09')

      expect(LifeInsurance.count).to eq(5)
      expect(page).to have_text('Nenhum registro encontrado')
      expect(page).to have_no_table
    end

    scenario 'exports the month in the insurer spreadsheet layout', :xlsx_service, flipper: { hr: :tenant } do
      visit life_insurance_movements_path
      click_on 'Exportar Excel'

      header = ['tpmvto', 'NR_Matricula', 'CPF', 'Nome', 'Dtnasc', 'Idade', 'Sexo', 'Premio', 'M1', 'MA2', 'IPA3', 'IFPD4', 'IC-M5', 'IF-M6',
                'Ass Fun Fam7']
      expect(page.response_headers['Content-Disposition']).to include('attachment', "movimentos-do-seguro-#{Date.current.iso8601}.xlsx")
      expect(downloaded_xlsx_rows('MME')).to eq(
        [header, [1, '04721755996', '047.217.559-96', 'JOSE SILVA', Date.new(1984, 11, 21), 41, 'M', 36.63, 115_000, 115_000, 115_000, 115_000,
                  57_500, 11_500, 6000]],
      )
      expect(downloaded_xlsx_rows('TRANSJR')).to eq([header])
      expect(downloaded_xlsx_rows('MM')).to eq(
        [header,
         [2, '11144477735', '111.444.777-35', 'ANA PAULA', Date.new(1998, 3, 15), 28, 'F', 35.04, 110_000, 110_000, 110_000, 110_000, 55_000,
          11_000, 6000],
         [3, '39053344705', '390.533.447-05', 'CARLOS LIMA', Date.new(1976, 12, 30), 49, 'M', 54.15, 170_000, 170_000, 170_000, 170_000, 85_000,
          17_000, 6000]],
      )
    end
  end

  context 'when the owner is signed in on a phone', :js, flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'keeps the employee and the movement without scrolling sideways' do
      visit life_insurance_movements_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'FUNCIONÁRIO')
      expect(page).to have_css('th', text: 'MOVIMENTO')
      expect(page).to have_no_css('th', text: 'EMPRESA')
      expect(page).to have_no_css('th', text: 'CAPITAL SEGURADO')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
