require 'rails_helper'

describe 'Holidays' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Feriados', slug: 'holidays') }

  before { travel_to(Time.zone.local(2026, 11, 11, 10)) }

  context 'without a signed in user' do
    scenario 'redirects the listing to the login screen' do
      visit holidays_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'does not create a holiday' do
      expect do
        page.driver.submit :post, holidays_path, { holiday: { date: '2026-04-29', name: 'Aniversário de Ipatinga' } }
      end.not_to change(Holiday, :count)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are no holidays in the year' do
      scenario 'shows the empty state message' do
        visit holidays_path

        expect(Holiday.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are holidays' do
      let!(:black_consciousness) { create(:holiday, tenant:) }
      let!(:all_souls) { create(:holiday, tenant:, date: Date.new(2026, 11, 2), name: 'Finados') }
      let!(:city_birthday) do
        create(:holiday, tenant:, date: Date.new(2026, 4, 29), name: 'Aniversário de Ipatinga', scope_type: 'municipal')
      end
      let!(:carnival) do
        create(:holiday, tenant:, date: Date.new(2027, 2, 8), name: 'Carnaval (segunda-feira)', kind_type: 'optional')
      end
      let!(:stranger_holiday) { create(:holiday, tenant: other_tenant, date: Date.new(2026, 7, 9), name: 'FERIADO DE OUTRA') }

      scenario 'lists the holidays of the current year from the registrations menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Feriados'
        end

        expect(page).to have_current_path(holidays_path)
        expect(Holiday.count).to eq(5)
        expect(html_table_to_rows).to eq(
          [
            %w[Data Nome Abrangência Tipo Ações],
            ['29/04/2026 (quarta-feira)', 'Aniversário de Ipatinga', 'Municipal', 'Feriado', 'Opções Alterar Excluir'],
            ['02/11/2026 (segunda-feira)', 'Finados', 'Nacional', 'Feriado', 'Opções Alterar Excluir'],
            ['20/11/2026 (sexta-feira)', 'Dia Nacional de Zumbi e da Consciência Negra', 'Nacional', 'Feriado',
             'Opções Alterar Excluir'],
          ],
        )
        expect(page).to have_link('Novo Feriado', href: new_holiday_path)
        expect(page).to have_no_text('FERIADO DE OUTRA')
      end

      scenario 'filters the holidays by year, name and scope' do
        visit holidays_path
        select '2027', from: 'Ano'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            %w[Data Nome Abrangência Tipo Ações],
            ['08/02/2027 (segunda-feira)', 'Carnaval (segunda-feira)', 'Nacional', 'Ponto facultativo', 'Opções Alterar Excluir'],
          ],
        )

        visit holidays_path
        select '2026', from: 'Ano'
        fill_in 'Nome do feriado', with: 'ipatinga'
        select 'Municipal', from: 'Abrangência'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            %w[Data Nome Abrangência Tipo Ações],
            ['29/04/2026 (quarta-feira)', 'Aniversário de Ipatinga', 'Municipal', 'Feriado', 'Opções Alterar Excluir'],
          ],
        )
      end

      scenario 'sorts the holidays by name and by date' do
        visit holidays_path
        click_on 'Nome'

        expect(html_table_to_rows.drop(1).map(&:second))
          .to eq(['Aniversário de Ipatinga', 'Dia Nacional de Zumbi e da Consciência Negra', 'Finados'])

        click_on 'Data'
        click_on 'Data'

        expect(html_table_to_rows.drop(1).map(&:second))
          .to eq(['Dia Nacional de Zumbi e da Consciência Negra', 'Finados', 'Aniversário de Ipatinga'])
      end

      scenario 'edits a holiday' do
        visit holidays_path
        within("#holiday_#{city_birthday.id} .inline-actions") { click_on 'Alterar' }

        fill_in 'Nome', with: 'Emancipação de Ipatinga'
        select 'Estadual', from: 'Abrangência'
        select 'Emenda', from: 'Tipo'

        expect { click_on 'Salvar Alterações' }.not_to change(Holiday, :count)

        expect(page).to have_current_path(holidays_path(year: 2026))
        expect(page).to have_text('Feriado atualizado com sucesso.')
        expect(city_birthday.reload).to have_attributes(date: Date.new(2026, 4, 29), name: 'Emancipação de Ipatinga',
                                                        scope_type: 'state', kind_type: 'bridge_day')
      end

      scenario 'removes a holiday' do
        visit holidays_path

        expect { page.driver.submit :delete, holiday_path(all_souls), {} }.to change(Holiday, :count).by(-1)

        expect(page).to have_current_path(holidays_path(year: 2026))
        expect(page).to have_text('Feriado excluído com sucesso.')
        expect(Holiday.exists?(all_souls.id)).to be(false)
      end

      scenario 'does not edit a holiday of another tenant' do
        visit edit_holiday_path(stranger_holiday)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when creating a holiday' do
      let!(:black_consciousness) { create(:holiday, tenant:) }

      scenario 'creates a municipal holiday' do
        visit holidays_path
        click_on 'Novo Feriado'

        fill_in 'Data', with: '2026-04-29'
        fill_in 'Nome', with: 'Aniversário de Ipatinga'
        select 'Municipal', from: 'Abrangência'
        select 'Feriado', from: 'Tipo'

        expect { click_on 'Cadastrar Feriado' }.to change(Holiday, :count).by(1)

        expect(page).to have_current_path(holidays_path(year: 2026))
        expect(page).to have_text('Feriado cadastrado com sucesso.')
        expect(Holiday.last).to have_attributes(tenant:, date: Date.new(2026, 4, 29), name: 'Aniversário de Ipatinga',
                                                scope_type: 'municipal', kind_type: 'holiday')
      end

      scenario 'shows the errors of a date that already has a holiday' do
        visit new_holiday_path

        fill_in 'Data', with: '2026-11-20'
        fill_in 'Nome', with: 'Outro feriado'

        expect { click_on 'Cadastrar Feriado' }.not_to change(Holiday, :count)

        expect(page).to have_text('Data já tem um feriado cadastrado')
      end
    end
  end

  context 'when a user without access to holidays is signed in' do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:holiday) { create(:holiday, tenant:) }

    before { login_as(admin, scope: :user) }

    scenario 'cannot open the listing nor remove a holiday' do
      visit holidays_path

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')

      expect { page.driver.submit :delete, holiday_path(holiday), {} }.not_to change(Holiday, :count)
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }
    let!(:holiday) { create(:holiday, tenant:) }

    before { login_as(owner, scope: :user) }

    scenario 'keeps the essential columns and collapses the actions into a menu' do
      visit holidays_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'DATA')
      expect(page).to have_no_css('th', text: 'ABRANGÊNCIA')

      within("#holiday_#{holiday.id}") do
        click_button 'Opções'
        click_on 'Alterar'
      end

      expect(page).to have_current_path(edit_holiday_path(holiday))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
