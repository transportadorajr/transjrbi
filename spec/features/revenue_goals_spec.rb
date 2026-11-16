require 'rails_helper'

describe 'Revenue goals registration', flipper: { revenue_goals: :tenant } do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Metas de faturamento', slug: 'revenue_goals') }
  let(:month) { Date.new(2026, 11, 1) }
  let!(:arcelor) { create(:atua_customer, tenant:, name: 'ARCELORMITTAL') }
  let!(:region) { create(:macro_region, tenant:, name: 'VALE DO AÇO/MG') }

  before do
    travel_to(Time.zone.local(2026, 11, 13, 10))
    create(:own_fleet, tenant:, plates: %w[RHJ5A50 AJR4391])
    create(:customer_group, tenant:, name: 'USIMINAS')
    create(:customer_group, tenant:, name: 'GERDAU', activated_at: nil)
  end

  def summary_cards
    all('#revenue_goals_summary .counter-card').map { it.text.squish }
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
        create(:revenue_goal, :region, tenant:, month:, macro_region: region, amount_cents: 6_000_000)
        create(:revenue_goal, tenant: other_tenant, month:, amount_cents: 99_900_000)
        create(:atua_transport_document, tenant:, plate: 'AJR4391', taker_code: arcelor.code, origin_macro_region: region, freight_cents: 3_500_000,
                                         issued_at: Time.zone.local(2026, 10, 15, 10))
      end

      scenario 'shows the goals of the month from the goals and projections menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Metas e projeções'
          click_on 'Metas de faturamento'
        end

        expect(page).to have_current_path(revenue_goals_path)
        expect(page).to have_css('h1.page-title', text: 'Metas de faturamento')
        expect(RevenueGoal.where(tenant:).count).to eq(3)
        expect(CustomerGroup.where(tenant:).count).to eq(2)
        expect(summary_cards).to eq(
          ['Transportadora R$ 150.000,00', 'Soma dos veículos R$ 40.000,00', 'Soma dos grupos R$ 0,00', 'Soma dos motoristas R$ 0,00',
           'Soma das regiões R$ 60.000,00'],
        )
        expect(page).to have_css('#revenue_goals_tabs .nav-link.active', text: 'Veículos 1')
        expect(html_table_to_rows(table: find_by_id('revenue_goals_vehicles'))).to eq(
          [['Placa', 'Meta', 'Participação na meta da transportadora', 'Faturado em Outubro de 2026'],
           ['AJR4391', 'R$ 40.000,00', '26,7%', 'R$ 35.000,00'], ['RHJ5A50', 'Sem meta', '-', 'R$ 0,00']],
        )
        expect(page).to have_css('#revenue_goals_vehicles .goal-plate', text: 'AJR4391')
        expect(html_table_to_rows(table: find_by_id('revenue_goals_customer_groups'))).to eq(
          [['Grupo de clientes', 'Meta', 'Participação na meta da transportadora', 'Faturado em Outubro de 2026'], ['USIMINAS', 'Sem meta', '-', 'R$ 0,00']],
        )
        expect(page).to have_no_css('#revenue_goals_customers')
        expect(html_table_to_rows(table: find_by_id('revenue_goals_regions'))).to eq(
          [['Macro região', 'Meta', 'Participação na meta da transportadora', 'Faturado em Outubro de 2026'],
           ['VALE DO AÇO/MG', 'R$ 60.000,00', '40,0%', 'R$ 35.000,00']],
        )
      end

      scenario 'changes the goals of the month' do
        visit revenue_goals_path
        click_on 'Alterar metas'

        expect(page).to have_css('h1.page-title', text: 'Alterar Metas')
        expect(find('.goal-line', text: 'AJR4391')).to have_text('Faturado em Outubro de 2026: R$ 35.000,00')
        expect(page).to have_css('[data-goal-lines-target="total"][data-section="regions"]', text: 'R$ 60.000,00')
        expect(page).to have_css('[data-goal-lines-target="share"][data-section="regions"]', text: '40,0% da meta da transportadora')
        fill_in 'Meta da transportadora', with: '180.000,00'
        fill_in 'AJR4391', with: ''
        fill_in 'RHJ5A50', with: '35.000,50'
        fill_in 'VALE DO AÇO/MG', with: ''

        expect { click_on 'Salvar Metas' }.to change(RevenueGoal, :count).by(-1)

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

        expect(summary_cards.first).to eq('Transportadora Sem meta')

        expect { click_on 'Copiar mês anterior' }.to change(RevenueGoal, :count).by(3)

        expect(page).to have_text('3 metas copiadas do mês anterior.')
        expect(summary_cards).to eq(
          ['Transportadora R$ 150.000,00', 'Soma dos veículos R$ 40.000,00', 'Soma dos grupos R$ 0,00', 'Soma dos motoristas R$ 0,00',
           'Soma das regiões R$ 60.000,00'],
        )
        expect(tenant.revenue_goals.for_month(month.next_month).count).to eq(3)
      end

      scenario 'moves to the previous month' do
        visit revenue_goals_path
        click_on 'Mês anterior'

        expect(page).to have_current_path(revenue_goals_path(month: '2026-10'))
        expect(summary_cards.first).to eq('Transportadora Sem meta')
      end
    end

    scenario 'creates the goals of a month' do
      visit edit_revenue_goals_path(month: '2026-11')
      fill_in 'Meta da transportadora', with: '200.000,00'
      fill_in 'AJR4391', with: '50.000,00'
      fill_in 'USIMINAS', with: '80.000,00'
      fill_in 'VALE DO AÇO/MG', with: '120.000,00'

      expect(page).to have_no_field('GERDAU')
      expect { click_on 'Salvar Metas' }.to change(RevenueGoal, :count).by(4)

      customer_goal = tenant.revenue_goals.customer_group.sole
      expect(customer_goal.customer_group.name).to eq('USIMINAS')
      expect(customer_goal.amount_cents).to eq(8_000_000)
      expect(tenant.revenue_goals.region.sole).to have_attributes(macro_region_id: region.id, amount_cents: 12_000_000)
      expect(summary_cards).to include('Soma dos grupos R$ 80.000,00', 'Soma das regiões R$ 120.000,00')
      expect(html_table_to_rows(table: find_by_id('revenue_goals_customer_groups')).last).to eq(['USIMINAS', 'R$ 80.000,00', '40,0%', 'R$ 0,00'])

      goal = tenant.revenue_goals.vehicle.sole
      expect(goal.month).to eq(month)
      expect(goal.plate).to eq('AJR4391')
      expect(goal.amount_cents).to eq(5_000_000)
      expect(tenant.revenue_goals.company.sole.amount_cents).to eq(20_000_000)
    end

    scenario 'rejects a plate outside the own fleet' do
      expect do
        page.driver.submit :patch, revenue_goals_path,
                           { revenue_goals: { month: '2026-11', vehicles_attributes: { '0' => { key: 'XYZ9K87', amount: '100,00' } } } }
      end.not_to change(RevenueGoal, :count)

      expect(page.status_code).to eq(422)
      expect(page).to have_text('O veículo XYZ9K87 não está na frota própria.')
    end

    scenario 'rejects a deactivated customer group without a goal' do
      gerdau = tenant.customer_groups.find_by!(name: 'GERDAU')

      expect do
        page.driver.submit :patch, revenue_goals_path,
                           { revenue_goals: { month: '2026-11', customer_groups_attributes: { '0' => { key: gerdau.id, amount: '100,00' } } } }
      end.not_to change(RevenueGoal, :count)

      expect(page.status_code).to eq(422)
      expect(page).to have_text("O grupo de clientes #{gerdau.id} não está ativo.")
    end

    context 'with a driver billed in the last months' do
      before do
        create(:atua_transport_document, tenant:, plate: 'AJR4391', driver_code: 11, driver_name: 'JOSE DA SILVA', freight_cents: 2_000_000,
                                         issued_at: Time.zone.local(2026, 10, 3, 10))
      end

      scenario 'creates the goal of the driver' do
        visit edit_revenue_goals_path(month: '2026-11')
        fill_in 'JOSE DA SILVA', with: '30.000,00'

        expect { click_on 'Salvar Metas' }.to change(RevenueGoal, :count).by(1)

        expect(tenant.revenue_goals.driver.sole).to have_attributes(driver_code: 11, amount_cents: 3_000_000)
        expect(html_table_to_rows(table: find_by_id('revenue_goals_drivers'))).to eq(
          [['Motorista', 'Meta', 'Participação na meta da transportadora', 'Faturado em Outubro de 2026'], ['JOSE DA SILVA', 'R$ 30.000,00', '-', 'R$ 20.000,00']],
        )
      end
    end

    context 'with more macro regions than a page' do
      before do
        (1..11).each { |index| create(:macro_region, tenant:, name: format('REGIÃO %02d', index), state: 'SP') }
      end

      scenario 'pages the regions and keeps their tab open' do
        visit revenue_goals_path(month: '2026-11')

        expect(page).to have_css('#revenue_goals_tabs .nav-link.active', text: 'Veículos')
        expect(html_table_to_rows(table: find_by_id('revenue_goals_regions')).size).to eq(11)
        expect(MacroRegion.where(tenant:).count).to eq(12)

        within('#revenue_goals_regions_pane .table-pagination') { click_on '2' }

        expect(page).to have_current_path(revenue_goals_path(month: '2026-11', regions_page: 2, tab: 'regions'))
        expect(page).to have_css('#revenue_goals_tabs .nav-link.active', text: 'Regiões')
        expect(page).to have_css('#revenue_goals_regions_pane.active')
        expect(html_table_to_rows(table: find_by_id('revenue_goals_regions')).drop(1).map(&:first)).to eq(['REGIÃO 11', 'VALE DO AÇO/MG'])
        expect(html_table_to_rows(table: find_by_id('revenue_goals_vehicles')).drop(1).map(&:first)).to eq(%w[AJR4391 RHJ5A50])
      end
    end

    scenario 'redirects an invalid month back to the current month' do
      visit revenue_goals_path(month: 'novembro')

      expect(page).to have_current_path(revenue_goals_path)
      expect(page).to have_text('Mês não é válido')
    end
  end

  context 'when the goals are changed in the browser', :js do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before do
      create(:revenue_goal, tenant:, month:, amount_cents: 20_000_000)
      create(:atua_transport_document, tenant:, plate: 'AJR4391', taker_code: arcelor.code, origin_macro_region: region, freight_cents: 3_500_000,
                                       issued_at: Time.zone.local(2026, 10, 15, 10))
      login_as(owner, scope: :user)
    end

    scenario 'sums the goals of each tab as they are typed' do
      visit edit_revenue_goals_path(month: '2026-11')
      fill_in 'AJR4391', with: '4000000'
      fill_in 'RHJ5A50', with: '1000000'

      expect(page).to have_css('[data-goal-lines-target="total"][data-section="vehicles"]', text: 'R$ 50.000,00')
      expect(page).to have_css('[data-goal-lines-target="share"][data-section="vehicles"]', text: '25,0% da meta da transportadora')

      click_on 'Regiões'
      fill_in 'VALE DO AÇO/MG', with: '9000000'

      expect(page).to have_css('[data-goal-lines-target="total"][data-section="regions"]', text: 'R$ 90.000,00')
      expect { click_on 'Salvar Metas' }.to change(RevenueGoal, :count).by(3)

      expect(page).to have_text('Metas salvas com sucesso.')
      expect(tenant.revenue_goals.region.sole.amount_cents).to eq(9_000_000)
      expect(tenant.revenue_goals.vehicle.pluck(:plate, :amount_cents)).to contain_exactly(['AJR4391', 4_000_000], ['RHJ5A50', 1_000_000])
    end

    scenario 'keeps the goal lines inside a phone screen' do
      visit edit_revenue_goals_path(month: '2026-11')
      use_mobile_screen(width: 360)

      expect(page).to have_css('.goal-line .goal-plate', text: 'AJR4391', visible: :visible)
      expect(page).to have_field('AJR4391', visible: :visible)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)

      visit revenue_goals_path(month: '2026-11')

      expect(page).to have_css('#revenue_goals_vehicles td', text: 'AJR4391', visible: :visible)
      expect(page).to have_no_css('#revenue_goals_vehicles th', text: 'PARTICIPAÇÃO NA META DA TRANSPORTADORA', visible: :visible)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
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
