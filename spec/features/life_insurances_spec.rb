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
        within('.sidebar-desktop') do
          click_on 'Seguros'
          click_on 'Seguro de vida'
        end

        expect(page).to have_current_path(life_insurances_path)
        expect(LifeInsurance.count).to eq(5)
        expect(html_table_to_rows).to eq(
          [
            ['Funcionário', 'Empresa', 'Capital segurado', 'Morte do cônjuge', 'Morte de filhos', 'Assistência funeral familiar', 'Prêmio', 'Ações'],
            ['ANA PAULA', 'MM Espinola', 'R$ 170.000,00', 'R$ 85.000,00', 'R$ 17.000,00', 'R$ 6.000,00', 'R$ 54,15', 'Opções Alterar Excluir do seguro'],
            ['JOSE SILVA', 'MME', 'R$ 115.000,00', 'R$ 57.500,00', 'R$ 11.500,00', 'R$ 6.000,00', 'R$ 36,63', 'Opções Alterar Excluir do seguro'],
          ],
        )
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(
          ['Segurados 2', 'Sem seguro 2', 'Inativos com seguro 0', 'Prêmio mensal R$ 90,78', 'Prêmio MME (1) R$ 36,63', 'Prêmio MM Espinola (1) R$ 54,15'],
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
          ['Segurados 1', 'Sem seguro 1', 'Inativos com seguro 0', 'Prêmio mensal R$ 54,15', 'Prêmio MM Espinola (1) R$ 54,15'],
        )
      end

      scenario 'sorts the insured employees by premium' do
        visit life_insurances_path(sort: 'premium', direction: 'asc')

        expect(LifeInsurance.count).to eq(5)
        expect(html_table_to_rows.drop(1).map { |row| [row.first, row[-2]] }).to eq([['JOSE SILVA', 'R$ 36,63'], ['ANA PAULA', 'R$ 54,15']])
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
        expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Segurados 0', 'Sem seguro 3', 'Inativos com seguro 0', 'Prêmio mensal R$ 0,00'])
      end
    end

    context 'when an uninsured employee has the data the insurer needs' do
      before { carlos.update!(born_on: Date.new(1985, 4, 2)) }

      scenario 'includes the employee from the uninsured list' do
        visit uninsured_employees_path
        within("#employee_#{carlos.id}") { click_on 'Incluir no seguro', match: :first }

        expect(page).to have_field('life_insurance[employee_id]', with: carlos.id.to_s, type: :hidden)
        expect(page).to have_field('Data de inclusão', with: '2026-11-24')
        fill_in 'Data de inclusão', with: '2026-11-20'

        expect { click_on 'Incluir no Seguro' }.to change(LifeInsurance, :count).by(1)

        expect(page).to have_current_path(life_insurances_path)
        expect(page).to have_text('Funcionário incluído no seguro de vida.')
        expect(LifeInsurance.last).to have_attributes(tenant:, employee: carlos, life_insurance_policy: mm_policy, capital_cents: 11_000_000,
                                                      included_on: Date.new(2026, 11, 20), excluded_on: nil, capital_changed_on: nil)
        expect(LifeInsurance.last[:capital_cents]).to be_nil
      end

      scenario 'includes the employee with an own capital' do
        visit new_life_insurance_path(employee_id: carlos.id)
        fill_in 'Capital próprio', with: '150.000,00'

        expect { click_on 'Incluir no Seguro' }.to change(LifeInsurance, :count).by(1)

        expect(LifeInsurance.last).to have_attributes(employee: carlos, capital_cents: 15_000_000, included_on: Date.new(2026, 11, 24))
      end
    end

    scenario 'does not include an employee without the insurer data or the company policy' do
      visit new_life_insurance_path(employee_id: carlos.id)

      expect { click_on 'Incluir no Seguro' }.not_to change(LifeInsurance, :count)

      expect(page).to have_text('Funcionário precisa ter CPF e data de nascimento cadastrados para a seguradora')

      transjr = create(:employee, tenant:, name: 'PEDRO TRANSJR', legal_id: '86288366757', born_on: Date.new(1990, 1, 1))
      visit new_life_insurance_path(employee_id: transjr.id)

      expect { click_on 'Incluir no Seguro' }.not_to change(LifeInsurance, :count)

      expect(page).to have_text('Funcionário é da empresa TransJR, que ainda não tem apólice cadastrada')
    end

    context 'when an employee is insured' do
      let!(:jose_insurance) { create(:life_insurance, employee: jose, life_insurance_policy: mme_policy, included_on: Date.new(2026, 1, 5)) }

      scenario 'changes the capital with the date it starts' do
        visit life_insurances_path
        within("#life_insurance_#{jose_insurance.id}") { click_on 'Alterar', match: :first }

        expect(page).to have_select('life_insurance[employee_id]', selected: 'JOSE SILVA', disabled: true)
        fill_in 'Capital próprio', with: '200.000,00'

        expect { click_on 'Salvar Alterações' }.not_to change(LifeInsurance, :count)

        expect(page).to have_text('Vigência do novo capital não pode ficar em branco')

        fill_in 'Vigência do novo capital', with: '2026-11-15'
        click_on 'Salvar Alterações'

        expect(page).to have_text('Seguro de vida atualizado com sucesso.')
        expect(jose_insurance.reload).to have_attributes(capital_cents: 20_000_000, capital_changed_on: Date.new(2026, 11, 15),
                                                         included_on: Date.new(2026, 1, 5), excluded_on: nil)
      end

      scenario 'excludes the employee from the life insurance' do
        visit life_insurances_path
        within("#life_insurance_#{jose_insurance.id}") { click_on 'Excluir do seguro', match: :first }

        expect(page).to have_text('JOSE SILVA deixa de estar coberto a partir desta data')
        fill_in 'Data de exclusão', with: '2026-11-23'

        expect { click_on 'Excluir do Seguro' }.not_to change(LifeInsurance, :count)

        expect(page).to have_current_path(life_insurances_path)
        expect(page).to have_text('Funcionário excluído do seguro de vida.')
        expect(jose_insurance.reload.excluded_on).to eq(Date.new(2026, 11, 23))
        expect(page).to have_no_css("#life_insurance_#{jose_insurance.id}")
      end

      scenario 'does not exclude before the inclusion' do
        visit new_life_insurance_exclusion_path(jose_insurance)
        fill_in 'Data de exclusão', with: '2025-12-31'
        click_on 'Excluir do Seguro'

        expect(page).to have_text('Data de exclusão não pode ser anterior à inclusão')
        expect(jose_insurance.reload.excluded_on).to be_nil
      end

      scenario 'warns about a deactivated employee still insured' do
        jose.update!(activated: false)
        visit life_insurances_path(employee_status: 'deactivated')

        expect(LifeInsurance.count).to eq(1)
        expect(html_table_to_rows.drop(1).map(&:first)).to eq(['JOSE SILVA Inativo'])
        expect(all('.counter-card').map { |card| card.text.squish }.third).to eq('Inativos com seguro 1')
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

      expect(page).to have_css('.page-header .page-title', text: 'Seguro de vida')
      expect(page).to have_no_css('.page-header', text: 'Movimentos do seguro')
      expect(all('#life_insurance_related_links a').map { |link| link.text.squish }).to eq(['Movimentos do seguro', 'Sem seguro de vida', 'Apólices'])
      expect(page.evaluate_script("document.querySelector('.page-title').getBoundingClientRect().width > 200")).to be(true)
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

    scenario 'picks the employee and includes them in the life insurance' do
      carlos.update!(born_on: Date.new(1985, 4, 2))
      visit new_life_insurance_path
      use_mobile_screen

      within('#life_insurance_employee_select') do
        find('.select2-trigger').click
        find('.select2-search').fill_in(with: 'carlos')
        find('.select2-option', text: 'CARLOS LIMA').click
      end
      fill_in 'Data de inclusão', with: '2026-11-20'

      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      expect { click_on 'Incluir no Seguro' }.to change(LifeInsurance, :count).by(1)

      expect(page).to have_text('Funcionário incluído no seguro de vida.')
      expect(LifeInsurance.last).to have_attributes(employee: carlos, life_insurance_policy: mm_policy, included_on: Date.new(2026, 11, 20))
    end

    scenario 'excludes an employee from the life insurance' do
      jose_insurance = LifeInsurance.find_by!(employee: jose)
      visit new_life_insurance_exclusion_path(jose_insurance)
      use_mobile_screen

      fill_in 'Data de exclusão', with: '2026-11-23'

      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      expect { accept_confirm { click_on 'Excluir do Seguro' } }.not_to change(LifeInsurance, :count)

      expect(page).to have_text('Funcionário excluído do seguro de vida.')
      expect(jose_insurance.reload.excluded_on).to eq(Date.new(2026, 11, 23))
    end
  end
end
