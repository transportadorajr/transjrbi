require 'rails_helper'

describe 'Maintenance order Atua posting', :maintenance, flipper: :maintenance do
  let!(:tenant) { create(:tenant) }
  let!(:resource) { create(:resource, name: 'Ordens de serviço', slug: 'maintenance_orders') }
  let!(:maintenance_resource) { create(:resource, name: 'Módulo de manutenção', slug: 'maintenance', writable: false) }
  let!(:maintenance_order) do
    create(:maintenance_order, tenant:, number: 7, plate: 'EXU1A23', status_type: 'finished', opened_at: Time.zone.local(2026, 11, 11, 8),
                               finished_at: Time.zone.local(2026, 11, 11, 17, 30), release_test_type: 'road_test')
  end

  before { travel_to(Time.zone.local(2026, 11, 12, 9)) }

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, user_type: :owner, name: 'ANA ESCRITÓRIO') }

    before { login_as(owner, scope: :user) }

    scenario 'posts a finished order through the modal', :js do
      visit maintenance_order_path(maintenance_order)

      expect(dl_to_hash('#atua_posting')).to eq('Nº OS ATUA' => '-', 'LANÇADA EM' => '-', 'LANÇADA POR' => '-', 'VERIFICAÇÃO' => 'Pendente')

      click_on 'Lançar no Atua'

      within('#maintenance_order_posting_modal') do
        expect(page).to have_field('Lançada em', with: '2026-11-12')
        fill_in 'Nº OS Atua', with: '4521'
        check 'Verificação OK'
        click_on 'Salvar lançamento'
      end

      expect(page).to have_text('Lançamento no Atua salvo com sucesso.')
      expect(maintenance_order.reload).to have_attributes(atua_order_number: '4521', posted_on: Date.new(2026, 11, 12), posted_by: owner,
                                                          posting_verified: true)
      expect(dl_to_hash('#atua_posting')).to eq('Nº OS ATUA' => '4521', 'LANÇADA EM' => '12/11/2026', 'LANÇADA POR' => 'ANA ESCRITÓRIO',
                                                'VERIFICAÇÃO' => 'OK')
      expect(page).to have_link('Alterar lançamento')
    end

    scenario 'keeps the posting modal open with the errors', :js do
      create(:maintenance_order, tenant:, number: 5, status_type: 'finished', atua_order_number: '4521')

      visit maintenance_order_path(maintenance_order)
      click_on 'Lançar no Atua'

      within('#maintenance_order_posting_modal') do
        fill_in 'Nº OS Atua', with: '4521'
        click_on 'Salvar lançamento'

        expect(page).to have_css('.alert-danger', text: 'Nº OS Atua já foi lançado na OS 5')
      end

      expect(maintenance_order.reload.posted_on).to be_nil
    end

    scenario 'opens the posting modal through a turbo stream' do
      visit edit_maintenance_order_posting_path(maintenance_order, format: :turbo_stream)

      expect(page.status_code).to eq(200)
      expect(page.body).to include('turbo-stream action="update" target="remote-container"')
      expect(page.body).to include('Lançamento no Atua')
    end

    scenario 'filters the orders waiting for the Atua posting' do
      posted_order = create(:maintenance_order, tenant:, number: 8, plate: 'GKT4567', status_type: 'finished',
                                                finished_at: Time.zone.local(2026, 11, 11, 18), atua_order_number: '4522',
                                                posted_on: Date.new(2026, 11, 12))
      create(:maintenance_order, tenant:, number: 9, plate: 'EXU9B87')

      visit maintenance_orders_path

      expect(MaintenanceOrder.count).to eq(3)
      expect(page).to have_css('.counter-card', text: "Aguardando lançamento no Atua\n1")

      within('#filtersModal') do
        select 'Concluídas sem lançamento', from: 'Lançamento no Atua'
        click_on 'Aplicar Filtros'
      end

      expect(html_table_to_rows.drop(1).map(&:first)).to eq(['7'])

      visit maintenance_orders_path(posting: 'posted')

      expect(html_table_to_rows.drop(1).map(&:first)).to eq([posted_order.number.to_s])
    end

    context 'when the order is still pending' do
      before { maintenance_order.update!(status_type: 'in_progress', finished_at: nil) }

      scenario 'shows no posting option and does not post the order' do
        visit maintenance_order_path(maintenance_order)

        expect(page).to have_css('h1', text: 'OS 7 · EXU1A23')
        expect(page).to have_no_link('Lançar no Atua')
        expect(page).to have_no_css('#atua_posting')

        page.driver.submit :patch, maintenance_order_posting_path(maintenance_order),
                           { maintenance_order_posting: { atua_order_number: '4521', posted_on: '2026-11-12' } }

        expect(maintenance_order.reload.atua_order_number).to be_nil
      end
    end
  end

  context 'when a user can only read the maintenance orders' do
    let!(:reader) { create(:user, tenant:) }
    let!(:access) { create(:access, user: reader, resource:, reads: true, creates: false) }
    let!(:maintenance_access) { create(:access, user: reader, resource: maintenance_resource, creates: false) }

    before { login_as(reader, scope: :user) }

    scenario 'sees the posting without the option to change it' do
      maintenance_order.update!(atua_order_number: '4521', posted_on: Date.new(2026, 11, 12))

      visit maintenance_order_path(maintenance_order)

      expect(dl_to_hash('#atua_posting')).to eq('Nº OS Atua' => '4521', 'Lançada em' => '12/11/2026', 'Lançada por' => '-',
                                                'Verificação' => 'Pendente')
      expect(page).to have_no_link('Alterar lançamento')

      page.driver.submit :patch, maintenance_order_posting_path(maintenance_order),
                         { maintenance_order_posting: { atua_order_number: '9999', posted_on: '2026-11-12' } }

      expect(maintenance_order.reload.atua_order_number).to eq('4521')
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'wraps the posting button without scrolling sideways' do
      visit maintenance_order_path(maintenance_order)
      use_mobile_screen

      expect(page).to have_link('Lançar no Atua')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
