require 'rails_helper'

describe 'Revenue projection', flipper: { revenue_projection: :tenant } do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Projeção de faturamento', slug: 'revenue_projection', writable: false) }
  let(:now) { Time.zone.local(2026, 11, 11, 15) }

  before { travel_to(now) }

  def issue_regular_days(tenant, from, to)
    (from..to).each do |date|
      next if date.sunday?

      create(:atua_transport_document, tenant:, issued_at: date.in_time_zone.change(hour: 10), freight_cents: date.saturday? ? 50_000 : 100_000)
    end
  end

  context 'without a signed in user' do
    scenario 'redirects to the login screen' do
      visit revenue_projection_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'with twelve weeks of regular billing' do
      before do
        issue_regular_days(tenant, Date.new(2026, 8, 17), Date.new(2026, 11, 11))
        issue_regular_days(other_tenant, Date.new(2026, 11, 2), Date.new(2026, 11, 11))
        create(:atua_import, tenant:, status_type: 'succeeded', finished_at: now)
      end

      scenario 'shows the realized and the projected billing of the month and of the week from the intelligence menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Inteligência'
          click_on 'Projeção de faturamento'
        end

        expect(page).to have_current_path(revenue_projection_path)
        expect(page).to have_css('h1.page-title', text: 'Projeção de faturamento')
        expect(page).to have_text('Dados do Atua até 11/11/2026 15:00')
        expect(page).to have_text('Mês de novembro de 2026')
        expect(dl_to_hash('#month_projection')).to eq(
          'Faturado até 11/11/2026 15:00' => 'R$ 8.500,00',
          'Projeção até 30/11/2026 23:59' => 'R$ 23.000,00',
          'Faixa provável' => 'R$ 23.000,00 a R$ 23.000,00',
        )
        expect(page).to have_text('Semana de 08/11 a 14/11')
        expect(dl_to_hash('#week_projection')).to eq(
          'Faturado até 11/11/2026 15:00' => 'R$ 3.000,00',
          'Projeção até 14/11/2026 23:59' => 'R$ 5.500,00',
          'Faixa provável' => 'R$ 5.500,00 a R$ 5.500,00',
        )
        expect(page).to have_text('Faturamento acumulado do mês')
        expect(page).to have_no_text('Projeção ajustada pelos feriados')
      end

      context 'with a holiday ahead in the month' do
        before { create(:holiday, tenant:) }

        scenario 'reduces the projection of the month and warns about the holiday' do
          visit revenue_projection_path

          expect(dl_to_hash('#month_projection')).to include('Projeção até 30/11/2026 23:59' => 'R$ 22.300,00')
          expect(dl_to_hash('#week_projection')).to include('Projeção até 14/11/2026 23:59' => 'R$ 5.500,00')
          expect(page).to have_text(
            'Projeção ajustada pelos feriados do período: 20/11 Dia Nacional de Zumbi e da Consciência Negra.', count: 1
          )
        end
      end
    end

    context 'without billing history' do
      before { create(:atua_transport_document, tenant:, issued_at: now.change(hour: 9), freight_cents: 100_000) }

      scenario 'projects only the realized billing and tells that there is no history' do
        visit revenue_projection_path

        expect(page).to have_text('Nenhuma importação do Atua concluída ainda')
        expect(dl_to_hash('#month_projection')).to eq(
          'Faturado até 11/11/2026 15:00' => 'R$ 1.000,00',
          'Projeção até 30/11/2026 23:59' => 'R$ 1.000,00',
          'Faixa provável' => 'R$ 1.000,00 a R$ 1.000,00',
        )
        expect(page).to have_text('Ainda não há histórico de faturamento suficiente', count: 2)
      end
    end
  end

  context 'when the feature is turned off for the tenant' do
    let!(:owner) { create(:user, tenant: other_tenant, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'does not show the menu nor the screen' do
      visit root_path

      within('.sidebar-desktop') { expect(page).to have_no_link('Projeção de faturamento') }

      visit revenue_projection_path

      expect(page.status_code).to eq(404)
    end
  end

  context 'when a user without access to the projection is signed in' do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }

    before { login_as(admin, scope: :user) }

    scenario 'cannot open the screen' do
      visit revenue_projection_path

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before do
      issue_regular_days(tenant, Date.new(2026, 10, 19), Date.new(2026, 11, 11))
      login_as(owner, scope: :user)
    end

    scenario 'stacks the cards and does not scroll sideways' do
      visit revenue_projection_path
      use_mobile_screen

      expect(page).to have_css('#month_projection')
      expect(page).to have_css('#week_projection')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
