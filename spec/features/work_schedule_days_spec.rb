require 'rails_helper'

describe 'Work schedule days', :hr do
  let!(:tenant) { create(:tenant) }
  let!(:hr_resource) { create(:resource, name: 'Módulo de RH', slug: 'hr', writable: false) }
  let!(:resource) { create(:resource, name: 'Escala de folgas', slug: 'work_schedules') }
  let!(:driver) { create(:driver, tenant:, code: 501) }
  let!(:jose) { create(:employee, tenant:, name: 'JOSE SILVA', legal_id: '52998224725', driver:) }
  let!(:ipatinga) { create(:city, tenant:, name: 'Ipatinga', state: 'MG', base: true) }
  let!(:cubatao) { create(:city, tenant:, name: 'Cubatão', state: 'SP') }

  around { |example| travel_to(Time.zone.local(2026, 11, 25, 10)) { example.run } }

  def select_day_off_city(search, city)
    within('#work_schedule_day_city_select') do
      find('.select2-trigger').click
      find('.select2-search').fill_in(with: search)
      find('.select2-option', text: city).click
    end
  end

  context 'when the owner is signed in', :js, flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when the driver took days off in a city before' do
      before do
        create(:work_schedule_day, employee: jose, date: Date.new(2026, 11, 1), city: ipatinga)
        create(:work_schedule_day, employee: jose, date: Date.new(2026, 11, 8), city: ipatinga)
      end

      scenario 'enters a day off with the suggested city' do
        visit work_schedules_path
        within("#employee_#{jose.id}") { click_on 'Lançar folga ou afastamento' }

        within('#work_schedule_day_modal') do
          expect(page).to have_text('Lançar para JOSE SILVA')
          expect(page).to have_css('#work_schedule_day_city_select .select2-single-value', text: 'Ipatinga/MG (base)')
          expect(page).to have_field('De', with: '2026-11-25')

          expect { click_on 'Lançar' }.to change(WorkScheduleDay, :count).by(1)
        end

        expect(page).to have_text('Lançamento salvo na escala.')
        expect(page).to have_css("#employee_#{jose.id}", text: 'Folga na base')
        expect(WorkScheduleDay.last).to have_attributes(tenant:, employee: jose, date: Date.new(2026, 11, 25), kind_type: 'day_off',
                                                        city: ipatinga)
      end
    end

    context 'when the driver is on a trip' do
      before do
        manifest = create(:atua_manifest, tenant:, trip_started_at: Time.zone.local(2026, 11, 22, 8), closed_at: Time.zone.local(2026, 11, 24, 18))
        transport_document = create(:atua_transport_document, tenant:, driver_code: 501)
        create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: transport_document.number)
      end

      scenario 'searches the city of the day off by name' do
        visit work_schedules_path
        within("#employee_#{jose.id}") { click_on 'Lançar folga ou afastamento' }

        within('#work_schedule_day_modal') do
          expect(page).to have_css('#work_schedule_day_city_select_label', text: 'Cidade da folga')

          find('#work_schedule_day_city_select .select2-trigger').click
          expect(all('.select2-option').map(&:text)).to eq(['Ipatinga/MG (base)', 'Cubatão/SP'])

          find('.select2-search').fill_in(with: 'cubatao')
          expect(all('.select2-option').map(&:text)).to eq(['Cubatão/SP'])

          find('.select2-option', text: 'Cubatão/SP').click
          fill_in 'De', with: '2026-11-26'
          fill_in 'Até', with: '2026-11-26'

          expect { click_on 'Lançar' }.to change(WorkScheduleDay, :count).by(1)
        end

        expect(WorkScheduleDay.last).to have_attributes(date: Date.new(2026, 11, 26), city: cubatao)
      end

      scenario 'requires the city of the day off' do
        visit work_schedules_path
        within("#employee_#{jose.id}") { click_on 'Lançar folga ou afastamento' }

        within('#work_schedule_day_modal') do
          fill_in 'De', with: '2026-11-26'
          fill_in 'Até', with: '2026-11-26'

          expect { click_on 'Lançar' }.not_to change(WorkScheduleDay, :count)

          expect(page).to have_css('.invalid-feedback', text: 'não pode ficar em branco')
          expect(page).to have_css('#work_schedule_day_city_select')
        end
      end

      scenario 'blocks a day off on a trip day and keeps the modal open' do
        visit work_schedules_path
        within("#employee_#{jose.id}") { click_on 'Lançar folga ou afastamento' }

        within('#work_schedule_day_modal') do
          fill_in 'De', with: '2026-11-24'
          fill_in 'Até', with: '2026-11-24'
          select_day_off_city('cuba', 'Cubatão/SP')

          expect { click_on 'Lançar' }.not_to change(WorkScheduleDay, :count)

          expect(page).to have_text('cai em dia de viagem do motorista: 24/11/2026')
        end
      end

      scenario 'enters a leave for a period on trip days' do
        visit work_schedules_path
        within("#employee_#{jose.id}") { click_on 'Lançar folga ou afastamento' }

        within('#work_schedule_day_modal') do
          select 'Afastamento', from: 'Tipo'
          fill_in 'De', with: '2026-11-23'
          fill_in 'Até', with: '2026-11-24'
          select 'Atestado médico', from: 'Motivo do afastamento'

          expect { click_on 'Lançar' }.to change(WorkScheduleDay, :count).by(2)
        end

        expect(page).to have_text('Lançamento salvo na escala.')
        expect(WorkScheduleDay.order(:date).pluck(:date, :kind_type, :leave_reason_type, :city_id)).to eq(
          [[Date.new(2026, 11, 23), 'leave', 'medical_certificate', nil], [Date.new(2026, 11, 24), 'leave', 'medical_certificate', nil]],
        )
      end
    end

    context 'when the week has an entry' do
      let!(:entry) { create(:work_schedule_day, employee: jose, date: Date.new(2026, 11, 26), city: cubatao, notes: 'Folga combinada') }

      scenario 'shows the entry and removes it after the confirmation' do
        visit work_schedules_path
        click_on 'Ver o lançamento de 26/11/2026'

        within('#work_schedule_day_entry_modal') do
          expect(dl_to_hash('#work_schedule_day_data')).to eq(
            'Data' => '26/11/2026 (quinta-feira)', 'Tipo' => 'Folga', 'Cidade' => 'Cubatão/SP', 'Observações' => 'Folga combinada',
          )

          accept_confirm('Tem certeza que deseja excluir este lançamento da escala?') { click_on 'Excluir lançamento' }
        end

        expect(page).to have_text('Lançamento excluído da escala.')
        expect(WorkScheduleDay.count).to eq(0)
      end
    end
  end

  context 'when the owner is signed in on a phone', :js, flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before do
      use_mobile_screen
      login_as(owner, scope: :user)
    end

    scenario 'enters a day off from the card of the employee' do
      visit work_schedules_path
      within("#card_employee_#{jose.id}") { click_on 'Lançar folga ou afastamento' }

      within('#work_schedule_day_modal') do
        select_day_off_city('ipa', 'Ipatinga/MG (base)')

        expect { click_on 'Lançar' }.to change(WorkScheduleDay, :count).by(1)
      end

      expect(page).to have_css("#card_employee_#{jose.id}", text: 'Folga na base')
      expect(WorkScheduleDay.last).to have_attributes(tenant:, employee: jose, date: Date.new(2026, 11, 25), kind_type: 'day_off',
                                                      city: ipatinga, leave_reason_type: nil)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end

  context 'when a user can only read the schedule', flipper: :hr do
    let!(:operator) { create(:user, tenant:) }
    let!(:entry) { create(:work_schedule_day, employee: jose, date: Date.new(2026, 11, 26), city: cubatao) }

    before do
      create(:access, user: operator, resource: hr_resource, creates: false)
      create(:access, user: operator, resource:, creates: false)
      login_as(operator, scope: :user)
    end

    scenario 'sees the grid without the entry actions and cannot change it through forged requests' do
      visit work_schedules_path

      expect(page).to have_css("#employee_#{jose.id}", text: 'Folga fora da base')
      expect(page).to have_no_link('Lançar folga ou afastamento')

      expect do
        page.driver.submit :post, work_schedule_days_path,
                           { work_schedule_day: { employee_id: jose.id, kind_type: 'day_off', start_on: '2026-11-27', city_id: ipatinga.id } }
      end.not_to change(WorkScheduleDay, :count)

      expect do
        page.driver.submit :delete, work_schedule_day_path(entry), {}
      end.not_to change(WorkScheduleDay, :count)
    end
  end

  context 'when the entry belongs to another tenant', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }
    let!(:stranger_entry) { create(:work_schedule_day, employee: create(:employee, legal_id: '11144477735')) }

    before { login_as(owner, scope: :user) }

    scenario 'does not remove it' do
      page.driver.submit :delete, work_schedule_day_path(stranger_entry), {}

      expect(page.status_code).to eq(404)
      expect(WorkScheduleDay.count).to eq(1)
    end
  end
end
