require 'rails_helper'

describe 'Life insurance policies', :hr do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:hr_resource) { create(:resource, name: 'Módulo de RH', slug: 'hr', writable: false) }
  let!(:resource) { create(:resource, name: 'Seguro de vida', slug: 'life_insurances') }

  context 'without a signed in user', flipper: :hr do
    scenario 'redirects the listing to the login screen' do
      visit life_insurance_policies_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are policies' do
      let!(:mme_policy) { create(:life_insurance_policy, tenant:, company_type: 'mme', capital_cents: 11_500_000) }
      let!(:mm_policy) { create(:life_insurance_policy, tenant:, company_type: 'mm_espinola', capital_cents: 11_000_000) }

      before { create(:life_insurance_policy, tenant: other_tenant, company_type: 'transjr', capital_cents: 99_900_000) }

      scenario 'lists the policies from the life insurance screen' do
        visit life_insurances_path
        click_on 'Apólices'

        expect(page).to have_current_path(life_insurance_policies_path)
        expect(LifeInsurancePolicy.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Empresa', 'Capital segurado', 'Taxa do prêmio (‰)', 'Cônjuge (% do capital)', 'Filhos (% do capital)',
             'Assistência funeral familiar', 'Ações'],
            ['MME', 'R$ 115.000,00', '0,3185 ‰', '50%', '10%', 'R$ 6.000,00', ''],
            ['MM Espinola', 'R$ 110.000,00', '0,3185 ‰', '50%', '10%', 'R$ 6.000,00', ''],
          ],
        )
        expect(page).to have_link('Cadastrar Apólice', href: new_life_insurance_policy_path)
        expect(page).to have_no_text('R$ 999.000,00')
      end

      scenario 'filters the policies by company' do
        visit life_insurance_policies_path
        select 'MM Espinola', from: 'Empresa'
        click_on 'Aplicar Filtros'

        expect(page).to have_current_path(life_insurance_policies_path, ignore_query: true)
        expect(LifeInsurancePolicy.count).to eq(3)
        expect(html_table_to_rows.drop(1).map(&:first)).to eq(['MM Espinola'])
      end

      scenario 'registers the policy of the company still without one' do
        visit life_insurance_policies_path
        click_on 'Cadastrar Apólice'

        expect(page).to have_select('Empresa', options: %w[Selecione TransJR])
        select 'TransJR', from: 'Empresa'
        fill_in 'Capital segurado', with: '100.000,00'
        fill_in 'Taxa do prêmio (‰)', with: '0,3185'
        fill_in 'Cônjuge (% do capital)', with: '50'
        fill_in 'Filhos (% do capital)', with: '10'
        fill_in 'Assistência funeral familiar', with: '6.000,00'

        expect { click_on 'Cadastrar Apólice' }.to change(LifeInsurancePolicy, :count).by(1)

        expect(page).to have_current_path(life_insurance_policies_path)
        expect(page).to have_text('Apólice cadastrada com sucesso.')
        expect(page).to have_no_link('Cadastrar Apólice')
        expect(LifeInsurancePolicy.last).to have_attributes(
          tenant:, company_type: 'transjr', capital_cents: 10_000_000, premium_rate_per_mille: BigDecimal('0.3185'),
          spouse_percentage: 50, children_percentage: 10, funeral_assistance_cents: 600_000
        )
      end

      scenario 'edits a policy without changing its company' do
        visit life_insurance_policies_path
        within("#life_insurance_policy_#{mme_policy.id}") { click_on 'Alterar', match: :first }

        expect(page).to have_select('Empresa', selected: 'MME', disabled: true)
        expect(page).to have_field('Capital segurado', with: '115.000,00')
        expect(page).to have_field('Taxa do prêmio (‰)', with: '0,3185')
        fill_in 'Capital segurado', with: '120.000,00'
        fill_in 'Taxa do prêmio (‰)', with: '0,33'

        expect { click_on 'Salvar Alterações' }.not_to change(LifeInsurancePolicy, :count)

        expect(page).to have_text('Apólice atualizada com sucesso.')
        expect(mme_policy.reload).to have_attributes(company_type: 'mme', capital_cents: 12_000_000, premium_rate_per_mille: BigDecimal('0.33'),
                                                     spouse_percentage: 50, children_percentage: 10, funeral_assistance_cents: 600_000)
      end

      scenario 'shows the validation errors of the policy' do
        visit edit_life_insurance_policy_path(mm_policy)

        fill_in 'Capital segurado', with: '0'
        fill_in 'Taxa do prêmio (‰)', with: '1000'
        fill_in 'Cônjuge (% do capital)', with: '120'

        expect { click_on 'Salvar Alterações' }.not_to change { mm_policy.reload.attributes }

        expect(page).to have_text('Capital segurado deve ser maior que 0')
        expect(page).to have_text('Taxa do prêmio (‰) deve ser maior que 0 e menor que 1000')
        expect(page).to have_text('Cônjuge (% do capital) deve estar entre 0 e 100')
      end

      scenario 'does not open a policy of another tenant' do
        visit edit_life_insurance_policy_path(LifeInsurancePolicy.find_by!(tenant: other_tenant))

        expect(page.status_code).to eq(404)
      end
    end

    context 'when there are no policies' do
      scenario 'shows the empty listing' do
        visit life_insurance_policies_path

        expect(LifeInsurancePolicy.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end
  end

  context 'when the owner is signed in on a phone', :js, flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }
    let!(:mme_policy) { create(:life_insurance_policy, tenant:, company_type: 'mme', capital_cents: 11_500_000) }

    before { login_as(owner, scope: :user) }

    scenario 'keeps the company, the capital and the actions without scrolling sideways' do
      visit life_insurance_policies_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'EMPRESA')
      expect(page).to have_css('th', text: 'CAPITAL SEGURADO')
      expect(page).to have_no_css('th', text: 'TAXA DO PRÊMIO')
      expect(page).to have_no_css('th', text: 'ASSISTÊNCIA FUNERAL FAMILIAR')

      within("#life_insurance_policy_#{mme_policy.id}") { find("a[href='#{edit_life_insurance_policy_path(mme_policy)}']").click }

      expect(page).to have_current_path(edit_life_insurance_policy_path(mme_policy))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
