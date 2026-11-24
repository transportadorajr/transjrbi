require 'rails_helper'

describe 'Vacation balances', :hr do
  let!(:tenant) { create(:tenant) }
  let!(:hr_resource) { create(:resource, name: 'Módulo de RH', slug: 'hr', writable: false) }
  let!(:resource) { create(:resource, name: 'Férias', slug: 'vacations') }
  let!(:ana) { create(:employee, tenant:, name: 'ANA PAULA', legal_id: '11144477735', admitted_on: Date.new(2024, 10, 1)) }
  let!(:bruno) { create(:employee, tenant:, name: 'BRUNO COSTA', legal_id: '52998224725', admitted_on: Date.new(2025, 1, 10)) }

  around { |example| travel_to(Time.zone.local(2026, 11, 24, 10)) { example.run } }

  before do
    create(:vacation, employee: ana, start_on: Date.new(2025, 11, 1), end_on: Date.new(2025, 11, 20))
    create(:employee, tenant: create(:tenant), name: 'FUNCIONÁRIO DE OUTRA', admitted_on: Date.new(2024, 1, 1))
  end

  context 'when the owner is signed in', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'lists the periods with balance by deadline from the HR menu' do
      visit vacation_balances_path
      within('.sidebar-desktop') { click_on 'Férias a vencer' }

      expect(page).to have_css('.card', text: "Férias vencidas\n1")
      expect(page).to have_css('.card', text: "A vencer em até 60 dias\n1")
      expect(page).to have_css('.card', text: "Em dia, com saldo\n1")
      expect(Vacation.count).to eq(1)
      expect(html_table_to_rows).to eq(
        [
          ['Funcionário', 'Período aquisitivo', 'Gozar até', 'Saldo (dias)', 'Situação', 'Ações'],
          ['ANA PAULA', '01/10/2024 a 30/09/2025', '30/09/2026', '10', 'Vencidas', ''],
          ['BRUNO COSTA', '10/01/2025 a 09/01/2026', '09/01/2027', '30', 'A vencer', ''],
          ['ANA PAULA', '01/10/2025 a 30/09/2026', '30/09/2027', '30', 'Em dia', ''],
        ],
      )
      expect(page).to have_link('Lançar férias', href: new_vacation_path(employee_id: bruno.id))
      expect(page).to have_no_text('FUNCIONÁRIO DE OUTRA')
    end

    scenario 'filters the overdue periods and enters the vacation' do
      visit vacation_balances_path(status: 'overdue')

      expect(html_table_to_rows.drop(1).map(&:first)).to eq(['ANA PAULA'])

      click_on 'Lançar férias'

      expect(page).to have_current_path(new_vacation_path(employee_id: ana.id))
    end
  end
end
