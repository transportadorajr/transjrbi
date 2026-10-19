require 'rails_helper'

describe 'Insurance rate' do
  around { |example| travel_to(Time.zone.local(2026, 10, 19, 12)) { example.run } }

  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Alíquotas de seguro', slug: 'insurance_rates') }

  context 'without a signed in user' do
    scenario 'redirects the rate to the login screen' do
      visit insurance_rate_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'does not change the rate' do
      expect do
        page.driver.submit :patch, insurance_rate_path, { insurance_rate: { insurance_percentage: '0,03' } }
      end.not_to change(InsuranceRate, :count)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when the tenant has no rate' do
      scenario 'warns that the cargo insurance is not calculated' do
        visit insurance_rate_path

        expect(InsuranceRate.count).to eq(0)
        expect(page).to have_css('#missing_insurance_rate', text: 'Nenhuma alíquota de seguro cadastrada')
        expect(dl_to_hash('#insurance_rate_data')).to eq(
          'Alíquota do seguro' => '-',
          'Alíquota do IOF' => '-',
          'CT-es com o seguro' => '0',
          'Total de seguro calculado' => 'R$ 0,00',
        )
      end

      scenario 'registers the rate from the default values' do
        visit edit_insurance_rate_path

        expect(page).to have_field('Alíquota do seguro (%)', with: '0,022')
        expect(page).to have_field('Alíquota do IOF (%)', with: '7,38')

        expect { click_on 'Salvar Alterações' }.to change(InsuranceRate, :count).by(1)
          .and have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id)

        expect(page).to have_current_path(insurance_rate_path)
        expect(InsuranceRate.last).to have_attributes(tenant:, insurance_percentage: BigDecimal('0.022'), iof_percentage: BigDecimal('7.38'))
      end
    end

    context 'when the rate was calculated on transport documents' do
      let!(:insurance_rate) { create(:insurance_rate, tenant:) }

      before do
        create(:insurance_rate, tenant: other_tenant, insurance_percentage: BigDecimal('0.05'))
        create(:freight_expense, :insurance, tenant:, amount_cents: 197)
        create(:freight_expense, :insurance, tenant:, amount_cents: 212)
        create(:freight_expense, :insurance, tenant: other_tenant, amount_cents: 500)
      end

      scenario 'shows the rate of the tenant from the registrations menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Alíquota de seguro'
        end

        expect(page).to have_current_path(insurance_rate_path)
        expect(page).to have_css('h1.page-title', text: 'Alíquota de seguro')
        expect(dl_to_hash('#insurance_rate_data')).to eq(
          'Alíquota do seguro' => '0,022%',
          'Alíquota do IOF' => '7,38%',
          'CT-es com o seguro' => '2',
          'Total de seguro calculado' => 'R$ 4,09',
        )
        expect(page).to have_no_css('#missing_insurance_rate')
      end

      scenario 'changes the rate and recalculates the insurance of every transport document' do
        visit insurance_rate_path
        click_on 'Alterar'

        expect(page).to have_current_path(edit_insurance_rate_path)
        expect(page).to have_field('Alíquota do seguro (%)', with: '0,022')
        expect(page).to have_field('Alíquota do IOF (%)', with: '7,38')

        fill_in 'Alíquota do seguro (%)', with: '0,03'
        fill_in 'Alíquota do IOF (%)', with: '6,38'

        expect { click_on 'Salvar Alterações' }.to not_change(InsuranceRate, :count)
          .and have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id)

        expect(page).to have_current_path(insurance_rate_path)
        expect(page).to have_text('Alíquota atualizada com sucesso. O seguro dos CT-es será recalculado em segundo plano.')
        expect(insurance_rate.reload).to have_attributes(tenant:, insurance_percentage: BigDecimal('0.03'), iof_percentage: BigDecimal('6.38'))
      end

      scenario 'shows the errors of the percentages' do
        visit edit_insurance_rate_path
        fill_in 'Alíquota do seguro (%)', with: ''
        fill_in 'Alíquota do IOF (%)', with: '100'

        expect { click_on 'Salvar Alterações' }.to not_have_enqueued_job(FreightExpenses::CalculateJob)

        expect(page).to have_text('Alíquota do seguro (%) deve ser maior que 0 e menor que 100')
        expect(page).to have_text('Alíquota do IOF (%) deve ser maior ou igual a 0 e menor que 100')
        expect(insurance_rate.reload.insurance_percentage).to eq(BigDecimal('0.022'))
      end
    end

    scenario 'has no listing of rates' do
      visit '/insurance_rates'

      expect(page.status_code).to eq(404)
    end

    scenario 'has no creation of rates' do
      visit '/insurance_rate/new'

      expect(page.status_code).to eq(404)

      expect { page.driver.submit :post, insurance_rate_path, { insurance_rate: { insurance_percentage: '0,03' } } }
        .not_to change(InsuranceRate, :count)

      expect(page.status_code).to eq(404)
    end

    scenario 'has no removal of the rate' do
      create(:insurance_rate, tenant:)

      expect { page.driver.submit :delete, insurance_rate_path, {} }.not_to change(InsuranceRate, :count)

      expect(page.status_code).to eq(404)
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:insurance_rate) { create(:insurance_rate, tenant:) }

    before { login_as(operator, scope: :user) }

    context 'without access to the rate' do
      scenario 'is sent back with an access denied message' do
        visit insurance_rate_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the rate' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'shows the rate without the edit action' do
        visit insurance_rate_path

        expect(InsuranceRate.find_by!(tenant:)).to have_attributes(insurance_percentage: BigDecimal('0.022'), iof_percentage: BigDecimal('7.38'))
        expect(dl_to_hash('#insurance_rate_data')).to eq(
          'Alíquota do seguro' => '0,022%',
          'Alíquota do IOF' => '7,38%',
          'CT-es com o seguro' => '0',
          'Total de seguro calculado' => 'R$ 0,00',
        )
        expect(page).to have_no_link('Alterar')
      end

      scenario 'cannot change the rate through a forged request' do
        page.driver.submit :patch, insurance_rate_path, { insurance_rate: { insurance_percentage: '5' } }

        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
        expect(insurance_rate.reload.insurance_percentage).to eq(BigDecimal('0.022'))
      end
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }

    before do
      create(:insurance_rate, tenant:)
      login_as(admin, scope: :user)
    end

    scenario 'stacks the fields of the form without scrolling sideways' do
      visit edit_insurance_rate_path
      use_mobile_screen

      expect(page).to have_field('Alíquota do seguro (%)')
      expect(page).to have_field('Alíquota do IOF (%)')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
