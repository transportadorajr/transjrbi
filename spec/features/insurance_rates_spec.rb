require 'rails_helper'

describe 'Insurance rates' do
  around { |example| travel_to(Time.zone.local(2026, 10, 19, 12)) { example.run } }

  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Alíquotas de seguro', slug: 'insurance_rates') }

  context 'without a signed in user' do
    scenario 'redirects the listing to the login screen' do
      visit insurance_rates_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'does not create a rate' do
      expect do
        page.driver.submit :post, insurance_rates_path, { insurance_rate: { valid_from: '2026-10-01' } }
      end.not_to change(InsuranceRate, :count)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when there are no rates' do
      scenario 'shows the empty state message' do
        visit insurance_rates_path

        expect(InsuranceRate.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are rates' do
      let!(:september) { create(:insurance_rate, tenant:, valid_from: Date.new(2026, 9, 1), insurance_percentage: BigDecimal('0.02')) }
      let!(:october) { create(:insurance_rate, tenant:, valid_from: Date.new(2026, 10, 1)) }
      let!(:december) do
        create(:insurance_rate, tenant:, valid_from: Date.new(2026, 12, 1), insurance_percentage: BigDecimal('0.025'),
                                iof_percentage: BigDecimal('6.38'))
      end
      let!(:stranger_rate) { create(:insurance_rate, tenant: other_tenant, valid_from: Date.new(2026, 8, 1)) }

      scenario 'lists the rates of the tenant from the registrations menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Alíquotas de seguro'
        end

        expect(page).to have_current_path(insurance_rates_path)
        expect(InsuranceRate.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            ['Início da vigência', 'Alíquota do seguro', 'Alíquota do IOF', 'Situação', 'Ações'],
            ['01/12/2026', '0,025%', '6,38%', 'Futura', 'Opções Visualizar Alterar Excluir'],
            ['01/10/2026', '0,022%', '7,38%', 'Vigente', 'Opções Visualizar Alterar Excluir'],
            ['01/09/2026', '0,02%', '7,38%', 'Encerrada', 'Opções Visualizar Alterar Excluir'],
          ],
        )
        expect(page).to have_link('Nova Alíquota', href: new_insurance_rate_path)
        expect(page).to have_no_text('01/08/2026')
      end

      scenario 'filters the rates by the start of the validity' do
        visit insurance_rates_path
        fill_in 'Vigência a partir de', with: '2026-09-15'
        fill_in 'Vigência até', with: '2026-11-30'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows.drop(1).map(&:first)).to eq(['01/10/2026'])
      end

      context 'when a rate was calculated on transport documents' do
        before do
          create(:freight_expense, :insurance, tenant:, insurance_rate: october, amount_cents: 197)
          create(:freight_expense, :insurance, tenant:, insurance_rate: october, amount_cents: 212)
        end

        scenario 'shows the rate with its insurance' do
          visit insurance_rates_path
          click_on '01/10/2026'

          expect(page).to have_current_path(insurance_rate_path(october))
          expect(page).to have_css('h1.page-title', text: 'Alíquota de 01/10/2026')
          expect(dl_to_hash('#insurance_rate_data')).to eq(
            'Início da vigência' => '01/10/2026',
            'Alíquota do seguro' => '0,022%',
            'Alíquota do IOF' => '7,38%',
            'Situação' => 'Vigente',
            'CT-es com o seguro' => '2',
            'Total de seguro calculado' => 'R$ 4,09',
          )
        end
      end

      scenario 'does not show a rate of another tenant' do
        visit insurance_rate_path(stranger_rate)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when creating a rate' do
      scenario 'creates the rate and recalculates the freight expenses' do
        visit insurance_rates_path
        click_on 'Nova Alíquota'
        fill_in 'Início da vigência', with: '2026-11-01'
        fill_in 'Alíquota do seguro (%)', with: '0,022'
        fill_in 'Alíquota do IOF (%)', with: '7,38'

        expect { click_on 'Cadastrar Alíquota' }.to change(InsuranceRate, :count).by(1)
          .and have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id)

        insurance_rate = InsuranceRate.last
        expect(page).to have_current_path(insurance_rate_path(insurance_rate))
        expect(page).to have_text('Alíquota cadastrada com sucesso. O seguro dos CT-es será recalculado em segundo plano.')
        expect(insurance_rate).to have_attributes(tenant:, valid_from: Date.new(2026, 11, 1), insurance_percentage: BigDecimal('0.022'),
                                                  iof_percentage: BigDecimal('7.38'))
      end

      scenario 'shows the errors of the required fields' do
        visit new_insurance_rate_path

        expect { click_on 'Cadastrar Alíquota' }.to not_change(InsuranceRate, :count)
          .and not_have_enqueued_job(FreightExpenses::CalculateJob)

        expect(page).to have_text('Início da vigência não pode ficar em branco')
        expect(page).to have_text('Alíquota do seguro (%) deve ser maior que 0 e menor que 100')
      end
    end

    context 'when editing a rate' do
      let!(:insurance_rate) { create(:insurance_rate, tenant:) }

      scenario 'updates the rate and recalculates the freight expenses' do
        visit insurance_rates_path
        within("#insurance_rate_#{insurance_rate.id} .inline-actions") { click_on 'Alterar' }

        expect(page).to have_current_path(edit_insurance_rate_path(insurance_rate))
        expect(page).to have_field('Início da vigência', with: '2026-10-01')
        expect(page).to have_field('Alíquota do seguro (%)', with: '0,022')
        expect(page).to have_field('Alíquota do IOF (%)', with: '7,38')

        fill_in 'Alíquota do IOF (%)', with: '6,38'

        expect { click_on 'Salvar Alterações' }.to not_change(InsuranceRate, :count)
          .and have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id)

        expect(page).to have_current_path(insurance_rate_path(insurance_rate))
        expect(page).to have_text('Alíquota atualizada com sucesso. O seguro dos CT-es será recalculado em segundo plano.')
        expect(insurance_rate.reload).to have_attributes(valid_from: Date.new(2026, 10, 1), iof_percentage: BigDecimal('6.38'))
      end
    end

    context 'when removing a rate' do
      let!(:insurance_rate) { create(:insurance_rate, tenant:) }

      scenario 'removes the rate without insurance' do
        visit insurance_rates_path

        expect(page).to have_css("#insurance_rate_#{insurance_rate.id} a[data-turbo-confirm='Tem certeza que deseja excluir esta alíquota?']")

        expect { page.driver.submit :delete, insurance_rate_path(insurance_rate), {} }.to change(InsuranceRate, :count).by(-1)

        expect(page).to have_current_path(insurance_rates_path)
        expect(page).to have_text('Alíquota excluída com sucesso.')
      end

      context 'when the rate was already used' do
        before { create(:freight_expense, :insurance, tenant:, insurance_rate:) }

        scenario 'keeps the rate and explains why' do
          expect { page.driver.submit :delete, insurance_rate_path(insurance_rate), {} }.not_to change(InsuranceRate, :count)

          expect(page).to have_current_path(insurance_rates_path)
          expect(page).to have_text(
            'Não é possível excluir uma alíquota que já foi usada nos CT-es. Cadastre uma nova vigência para mudar o valor.',
          )
        end
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:insurance_rate) { create(:insurance_rate, tenant:) }

    before { login_as(operator, scope: :user) }

    context 'without access to the rates' do
      scenario 'is sent back with an access denied message' do
        visit insurance_rates_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the rates' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'lists the rates without the management actions' do
        visit insurance_rates_path

        expect(InsuranceRate.count).to eq(1)
        expect(html_table_to_rows).to eq(
          [
            ['Início da vigência', 'Alíquota do seguro', 'Alíquota do IOF', 'Situação', 'Ações'],
            ['01/10/2026', '0,022%', '7,38%', 'Vigente', ''],
          ],
        )
        expect(page).to have_no_link('Nova Alíquota')

        click_on '01/10/2026'

        expect(page).to have_no_link('Alterar')
      end

      scenario 'cannot change a rate through a forged request' do
        page.driver.submit :patch, insurance_rate_path(insurance_rate), { insurance_rate: { insurance_percentage: '5' } }

        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
        expect(insurance_rate.reload.insurance_percentage).to eq(BigDecimal('0.022'))
      end
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:insurance_rate) { create(:insurance_rate, tenant:) }

    before { login_as(admin, scope: :user) }

    scenario 'keeps the essential columns and collapses the actions into a menu' do
      visit insurance_rates_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'INÍCIO DA VIGÊNCIA')
      expect(page).to have_css('th', text: 'SITUAÇÃO')
      expect(page).to have_no_css('th', text: 'ALÍQUOTA DO SEGURO')

      within("#insurance_rate_#{insurance_rate.id}") do
        expect(page).to have_no_css('.inline-actions')
        click_button 'Opções'
        click_on 'Alterar'
      end

      expect(page).to have_current_path(edit_insurance_rate_path(insurance_rate))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
