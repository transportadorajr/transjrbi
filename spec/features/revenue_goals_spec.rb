require 'rails_helper'

describe 'Revenue goals registration', flipper: { revenue_goals: :tenant } do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Metas de faturamento', slug: 'revenue_goals') }
  let(:month) { Date.new(2026, 11, 1) }

  before do
    travel_to(Time.zone.local(2026, 11, 13, 10))
    create(:own_fleet, tenant:, plates: %w[RHJ5A50 AJR4391])
  end

  context 'without a signed in user' do
    scenario 'redirects the goals to the login screen' do
      visit revenue_goals_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'does not change the goals' do
      expect do
        page.driver.submit :patch, revenue_goals_path, { revenue_goals: { month: '2026-11', company: '100,00' } }
      end.not_to change(RevenueGoal, :count)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'with the goals of the month' do
      before do
        create(:revenue_goal, tenant:, month:, amount_cents: 15_000_000)
        create(:revenue_goal, :vehicle, tenant:, month:, plate: 'AJR4391', amount_cents: 4_000_000)
        create(:revenue_goal, tenant: other_tenant, month:, amount_cents: 99_900_000)
      end

      scenario 'shows the goals of the month from the registrations menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Metas de faturamento'
        end

        expect(page).to have_current_path(revenue_goals_path)
        expect(page).to have_css('h1.page-title', text: 'Metas de faturamento')
        expect(RevenueGoal.where(tenant:).count).to eq(2)
        expect(dl_to_hash('#revenue_goals_company')).to eq(
          'Mês' => 'Novembro de 2026', 'Meta da transportadora' => 'R$ 150.000,00', 'Soma das metas dos veículos' => 'R$ 40.000,00',
        )
        expect(html_table_to_rows).to eq([['Placa', 'Meta do veículo'], ['AJR4391', 'R$ 40.000,00'], ['RHJ5A50', 'Sem meta']])
      end

      scenario 'changes the goals of the month' do
        visit revenue_goals_path
        click_on 'Alterar metas'

        expect(page).to have_css('h1.page-title', text: 'Alterar Metas')
        fill_in 'Meta da transportadora', with: '180.000,00'
        fill_in 'AJR4391', with: ''
        fill_in 'RHJ5A50', with: '35.000,50'

        expect { click_on 'Salvar Metas' }.not_to change(RevenueGoal, :count)

        expect(page).to have_current_path(revenue_goals_path(month: '2026-11'))
        expect(page).to have_text('Metas salvas com sucesso.')
        expect(tenant.revenue_goals.for_month(month).map { [it.target_type, it.plate, it.amount_cents] })
          .to contain_exactly(['company', nil, 18_000_000], ['vehicle', 'RHJ5A50', 3_500_050])
        expect(other_tenant.revenue_goals.sole.amount_cents).to eq(99_900_000)
      end

      scenario 'keeps the goals when an amount is invalid' do
        visit edit_revenue_goals_path(month: '2026-11')
        fill_in 'RHJ5A50', with: '0'

        expect { click_on 'Salvar Metas' }.not_to change(RevenueGoal, :count)

        expect(page).to have_text('A meta do veículo RHJ5A50 deve ser maior que 0.')
        expect(tenant.revenue_goals.vehicle.sole.plate).to eq('AJR4391')
      end

      scenario 'copies the goals of the month to the next month' do
        visit revenue_goals_path(month: '2026-12')

        expect(dl_to_hash('#revenue_goals_company')['Meta da transportadora']).to eq('Sem meta')

        expect { click_on 'Copiar mês anterior' }.to change(RevenueGoal, :count).by(2)

        expect(page).to have_text('2 metas copiadas do mês anterior.')
        expect(dl_to_hash('#revenue_goals_company')).to eq(
          'Mês' => 'Dezembro de 2026', 'Meta da transportadora' => 'R$ 150.000,00', 'Soma das metas dos veículos' => 'R$ 40.000,00',
        )
        expect(tenant.revenue_goals.for_month(month.next_month).count).to eq(2)
      end

      scenario 'moves to the previous month' do
        visit revenue_goals_path
        click_on 'Mês anterior'

        expect(page).to have_current_path(revenue_goals_path(month: '2026-10'))
        expect(dl_to_hash('#revenue_goals_company')['Meta da transportadora']).to eq('Sem meta')
      end
    end

    scenario 'creates the goals of a month' do
      visit edit_revenue_goals_path(month: '2026-11')
      fill_in 'Meta da transportadora', with: '200.000,00'
      fill_in 'AJR4391', with: '50.000,00'

      expect { click_on 'Salvar Metas' }.to change(RevenueGoal, :count).by(2)

      goal = tenant.revenue_goals.vehicle.sole
      expect(goal.month).to eq(month)
      expect(goal.plate).to eq('AJR4391')
      expect(goal.amount_cents).to eq(5_000_000)
      expect(tenant.revenue_goals.company.sole.amount_cents).to eq(20_000_000)
    end

    scenario 'rejects a plate outside the own fleet' do
      expect do
        page.driver.submit :patch, revenue_goals_path,
                           { revenue_goals: { month: '2026-11', vehicles_attributes: { '0' => { plate: 'XYZ9K87', amount: '100,00' } } } }
      end.not_to change(RevenueGoal, :count)

      expect(page.status_code).to eq(422)
      expect(page).to have_text('O veículo XYZ9K87 não está na frota própria.')
    end

    scenario 'redirects an invalid month back to the current month' do
      visit revenue_goals_path(month: 'novembro')

      expect(page).to have_current_path(revenue_goals_path)
      expect(page).to have_text('Mês não é válido')
    end
  end

  context 'when an admin can only read the goals' do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }

    before do
      create(:access, user: admin, resource:, reads: true)
      login_as(admin, scope: :user)
    end

    scenario 'does not offer to change the goals' do
      visit revenue_goals_path

      expect(page).to have_css('h1.page-title', text: 'Metas de faturamento')
      expect(page).to have_no_link('Alterar metas')
      expect(page).to have_no_button('Copiar mês anterior')
    end

    scenario 'cannot copy the goals' do
      create(:revenue_goal, tenant:, month: month.prev_month)

      expect { page.driver.submit :post, replicate_revenue_goals_path(month: '2026-11'), {} }.not_to change(RevenueGoal, :count)
    end
  end

  context 'when the flag is off for the tenant' do
    let!(:other_owner) { create(:user, tenant: other_tenant, user_type: :owner) }

    before { login_as(other_owner, scope: :user) }

    scenario 'answers not found' do
      visit revenue_goals_path

      expect(page.status_code).to eq(404)
    end
  end
end
