require 'rails_helper'

describe 'Vacations', :hr do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:hr_resource) { create(:resource, name: 'Módulo de RH', slug: 'hr', writable: false) }
  let!(:resource) { create(:resource, name: 'Férias', slug: 'vacations') }
  let!(:jose) { create(:employee, tenant:, name: 'JOSE SILVA', legal_id: '52998224725', admitted_on: Date.new(2024, 3, 10)) }
  let!(:ana) do
    create(:employee, tenant:, name: 'ANA PAULA', legal_id: '11144477735', company_type: 'mme', admitted_on: Date.new(2024, 3, 10))
  end

  around { |example| travel_to(Time.zone.local(2026, 11, 24, 10)) { example.run } }

  context 'without a signed in user', flipper: :hr do
    scenario 'redirects the listing to the login screen' do
      visit vacations_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are vacations' do
      let!(:jose_vacation) do
        create(:vacation, employee: jose, start_on: Date.new(2025, 4, 1), end_on: Date.new(2025, 4, 20), sold_days: 10, notes: 'VENDEU 10 DIAS')
      end
      let!(:ana_vacation) { create(:vacation, employee: ana, start_on: Date.new(2025, 5, 5), end_on: Date.new(2025, 6, 3)) }

      before do
        stranger = create(:employee, tenant: other_tenant, name: 'FUNCIONÁRIO DE OUTRA', admitted_on: Date.new(2024, 3, 10))
        create(:vacation, employee: stranger)
      end

      scenario 'lists the vacations from the HR menu, the latest first' do
        visit vacations_path
        within('.sidebar-desktop') do
          click_on 'Ausências'
          click_on 'Férias'
        end

        expect(page).to have_current_path(vacations_path)
        expect(Vacation.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Funcionário', 'Saída', 'Retorno', 'Dias de férias', 'Dias vendidos', 'Período aquisitivo', 'Ações'],
            ['ANA PAULA', '05/05/2025 a 03/06/2025', '04/06/2025', '30', '0', '10/03/2024 a 09/03/2025', 'Opções Alterar Excluir'],
            ['JOSE SILVA', '01/04/2025 a 20/04/2025', '21/04/2025', '20', '10', '10/03/2024 a 09/03/2025', 'Opções Alterar Excluir'],
          ],
        )
        expect(page).to have_link('Lançar Férias', href: new_vacation_path)
        expect(page).to have_no_text('FUNCIONÁRIO DE OUTRA')
      end

      context 'when the employee has no admission date' do
        let!(:evandro) { create(:employee, tenant:, name: 'EVANDRO LUIS KAIM', legal_id: nil, admitted_on: nil) }

        before do
          create(:vacation, employee: evandro, acquisition_start_on: Date.new(2025, 2, 23), start_on: Date.new(2026, 2, 23),
                            end_on: Date.new(2026, 3, 24))
        end

        scenario 'lists the vacation with its acquisition period' do
          visit vacations_path(name: 'evandro')

          expect(Vacation.count).to eq(4)
          expect(html_table_to_rows).to eq(
            [
              ['Funcionário', 'Saída', 'Retorno', 'Dias de férias', 'Dias vendidos', 'Período aquisitivo', 'Ações'],
              ['EVANDRO LUIS KAIM', '23/02/2026 a 24/03/2026', '25/03/2026', '30', '0', '23/02/2025 a 22/02/2026', 'Opções Alterar Excluir'],
            ],
          )
        end
      end

      scenario 'filters the vacations by employee and month' do
        visit vacations_path(name: 'jose')

        expect(Vacation.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Funcionário', 'Saída', 'Retorno', 'Dias de férias', 'Dias vendidos', 'Período aquisitivo', 'Ações'],
            ['JOSE SILVA', '01/04/2025 a 20/04/2025', '21/04/2025', '20', '10', '10/03/2024 a 09/03/2025', 'Opções Alterar Excluir'],
          ],
        )

        visit vacations_path(month: '2025-06')

        expect(html_table_to_rows).to eq(
          [
            ['Funcionário', 'Saída', 'Retorno', 'Dias de férias', 'Dias vendidos', 'Período aquisitivo', 'Ações'],
            ['ANA PAULA', '05/05/2025 a 03/06/2025', '04/06/2025', '30', '0', '10/03/2024 a 09/03/2025', 'Opções Alterar Excluir'],
          ],
        )
      end

      scenario 'sorts the vacations by employee name' do
        visit vacations_path(sort: 'employee_name', direction: 'asc')

        expect(Vacation.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Funcionário', 'Saída', 'Retorno', 'Dias de férias', 'Dias vendidos', 'Período aquisitivo', 'Ações'],
            ['ANA PAULA', '05/05/2025 a 03/06/2025', '04/06/2025', '30', '0', '10/03/2024 a 09/03/2025', 'Opções Alterar Excluir'],
            ['JOSE SILVA', '01/04/2025 a 20/04/2025', '21/04/2025', '20', '10', '10/03/2024 a 09/03/2025', 'Opções Alterar Excluir'],
          ],
        )
      end

      scenario 'edits a vacation' do
        visit vacations_path
        within("#vacation_#{jose_vacation.id}") { click_on 'Alterar', match: :first }

        expect(page).to have_select('vacation[employee_id]', selected: 'JOSE SILVA', disabled: true)
        fill_in 'Saída', with: '2025-07-01'
        fill_in 'Último dia de férias', with: '2025-07-20'

        expect { click_on 'Salvar Alterações' }.not_to change(Vacation, :count)

        expect(page).to have_text('Férias atualizadas com sucesso.')
        expect(jose_vacation.reload).to have_attributes(employee: jose, acquisition_start_on: Date.new(2024, 3, 10), start_on: Date.new(2025, 7, 1),
                                                        end_on: Date.new(2025, 7, 20), sold_days: 10, notes: 'VENDEU 10 DIAS')
      end

      scenario 'deletes a vacation' do
        visit vacations_path

        expect { page.driver.submit :delete, vacation_path(ana_vacation), {} }.to change(Vacation, :count).by(-1)

        expect(page).to have_text('Férias excluídas com sucesso.')
        expect(Vacation.exists?(ana_vacation.id)).to be(false)
      end

      scenario 'exports the vacations to PDF' do
        visit vacations_path(format: :pdf)

        text = PDF::Inspector::Text.analyze(page.body).strings.join
        expect(page.response_headers['Content-Type']).to include('application/pdf')
        expect(Vacation.count).to eq(3)
        expect(text).to include('Relatório de Férias', 'ANA PAULA', 'JOSE SILVA', '01/04/2025', '21/04/2025', 'VENDEU 10 DIAS')
        expect(text).not_to include('FUNCIONÁRIO DE OUTRA')
      end

      scenario 'exports the vacations to Excel', :xlsx_service, flipper: { hr: :tenant, xlsx_export: :tenant } do
        visit vacations_path(name: 'jose')
        click_on 'Exportar Excel'

        expect(page.response_headers['Content-Disposition']).to include('attachment', "ferias-#{Date.current.iso8601}.xlsx")
        expect(downloaded_xlsx_rows.first).to eq(
          ['Funcionário', 'Período aquisitivo', 'Saída', 'Último dia', 'Dias vendidos', 'Observações', 'Criado em', 'Atualizado em',
           'Dias de férias', 'Retorno'],
        )
        expect(downloaded_xlsx_rows.drop(1).map { |row| row.first(6) + row.last(2) }).to eq(
          [['JOSE SILVA', Date.new(2024, 3, 10), Date.new(2025, 4, 1), Date.new(2025, 4, 20), 10, 'VENDEU 10 DIAS', 20, Date.new(2025, 4, 21)]],
        )
      end
    end

    context 'when there are no vacations' do
      scenario 'shows the empty listing' do
        visit vacations_path

        expect(Vacation.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    scenario 'enters a vacation with sold days' do
      visit new_vacation_path(employee_id: jose.id)

      fill_in 'Saída', with: '2025-04-01'
      fill_in 'Último dia de férias', with: '2025-04-20'
      fill_in 'Dias vendidos', with: '10'
      fill_in 'Observações', with: 'Vendeu 10 dias'

      expect { click_on 'Lançar Férias' }.to change(Vacation, :count).by(1)

      expect(page).to have_current_path(vacations_path)
      expect(page).to have_text('Férias lançadas com sucesso.')
      expect(Vacation.last).to have_attributes(tenant:, employee: jose, acquisition_start_on: Date.new(2024, 3, 10), start_on: Date.new(2025, 4, 1),
                                               end_on: Date.new(2025, 4, 20), sold_days: 10, notes: 'Vendeu 10 dias')
    end

    scenario 'shows the validation errors of the vacation' do
      visit new_vacation_path(employee_id: jose.id)

      fill_in 'Saída', with: '2025-04-01'
      fill_in 'Último dia de férias', with: '2025-04-03'

      expect { click_on 'Lançar Férias' }.not_to change(Vacation, :count)

      expect(page).to have_text('Último dia de férias deve deixar pelo menos 5 dias de férias')
    end
  end

  context 'when the owner is signed in on a phone', :js, flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before do
      use_mobile_screen
      login_as(owner, scope: :user)
    end

    scenario 'picks the employee and enters a vacation' do
      visit new_vacation_path

      within('#vacation_employee_select') do
        find('.select2-trigger').click
        find('.select2-search').fill_in(with: 'jose')
        find('.select2-option', text: 'JOSE SILVA').click
      end
      fill_in 'Saída', with: '2025-04-01'
      fill_in 'Último dia de férias', with: '2025-04-30'

      expect { click_on 'Lançar Férias' }.to change(Vacation, :count).by(1)

      expect(page).to have_text('Férias lançadas com sucesso.')
      expect(page).to have_css('td', text: 'JOSE SILVA')
      expect(page).to have_no_css('td', text: '01/05/2025')
      expect(Vacation.last).to have_attributes(tenant:, employee: jose, acquisition_start_on: Date.new(2024, 3, 10), start_on: Date.new(2025, 4, 1),
                                               end_on: Date.new(2025, 4, 30), sold_days: 0, notes: nil)
    end
  end

  context 'when a user with read access to the vacations is signed in', flipper: :hr do
    let!(:operator) { create(:user, tenant:) }
    let!(:vacation) { create(:vacation, employee: jose) }

    before do
      create(:access, user: operator, resource: hr_resource)
      create(:access, user: operator, resource:)
      login_as(operator, scope: :user)
    end

    scenario 'sees the listing without the actions and cannot change a vacation' do
      visit vacations_path

      expect(page).to have_css('td', text: 'JOSE SILVA')
      expect(page).to have_no_link('Lançar Férias')
      expect(page).to have_no_link('Alterar', exact: true)

      expect { page.driver.submit :delete, vacation_path(vacation), {} }.not_to change(Vacation, :count)
    end
  end
end
