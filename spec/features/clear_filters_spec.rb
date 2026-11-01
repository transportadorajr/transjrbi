require 'rails_helper'

describe 'Clearing the applied filters' do
  let!(:tenant) { create(:tenant) }
  let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

  before { login_as(admin, scope: :user) }

  context 'when listing the macro regions' do
    let!(:resource) { create(:resource, name: 'Macrorregiões', slug: 'macro_regions') }
    let!(:santos) { create(:macro_region, tenant:, name: 'Santos', state: 'SP') }
    let!(:betim) { create(:macro_region, tenant:, name: 'Betim', state: 'MG') }

    scenario 'disables the button while no filter is applied' do
      visit macro_regions_path

      expect(page).to have_link(href: '#filtersModal')
      within('.page-actions') { expect(page).to have_button('Limpar Filtros', disabled: true) }
    end

    scenario 'disables the button when only the sort and the page are in the URL' do
      visit macro_regions_path(sort: 'name', direction: 'desc', page: 1)

      expect(page).to have_link(href: '#filtersModal')
      within('.page-actions') { expect(page).to have_button('Limpar Filtros', disabled: true) }
    end

    scenario 'disables the button when the filters were submitted blank' do
      visit macro_regions_path(name: '')

      expect(page).to have_link(href: '#filtersModal')
      within('.page-actions') { expect(page).to have_button('Limpar Filtros', disabled: true) }
    end

    scenario 'removes every filter with one click' do
      visit macro_regions_path(name: 'Santos')

      expect(MacroRegion.count).to eq(2)
      expect(html_table_to_rows.drop(1).map(&:first)).to eq(['Santos'])

      within('.page-actions') { click_on 'Limpar Filtros' }

      expect(page).to have_current_path(macro_regions_path)
      expect(html_table_to_rows.drop(1).map(&:first)).to eq(%w[Betim Santos])
      within('.page-actions') { expect(page).to have_button('Limpar Filtros', disabled: true) }
    end

    scenario 'fits a phone screen next to the filters button', :js do
      use_mobile_screen
      visit macro_regions_path(name: 'Santos')

      within('.page-actions') { expect(page).to have_link('Limpar Filtros') }
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end

  context 'when viewing the freight billing' do
    let!(:resource) { create(:resource, name: 'Faturamento de fretes', slug: 'freight_billing', writable: false) }

    scenario 'goes back to the current week by customer group' do
      visit freight_billing_path(dimension: 'driver', start_date: '2020-01-01', end_date: '2020-01-31', plate: 'ABC1D23')

      within('.page-actions') { click_on 'Limpar Filtros' }

      week = FreightBillingFilterForm.preset_period(:week)
      expect(page).to have_current_path(freight_billing_path)
      expect(page).to have_text("#{I18n.l(week.first)} a #{I18n.l(week.last)}")
      expect(page).to have_css('.dashboard-segmented .btn-primary', text: 'Grupo de clientes')
      within('.page-actions') { expect(page).to have_button('Limpar Filtros', disabled: true) }
    end

    scenario 'clears from the modal to the same defaults' do
      visit freight_billing_path(dimension: 'driver', plate: 'ABC1D23')

      within('#filtersModal') { click_on 'Limpar Filtros' }

      expect(page).to have_current_path(freight_billing_path)
    end

    scenario 'disables the button when the selection already matches the defaults' do
      week = FreightBillingFilterForm.preset_period(:week)
      visit freight_billing_path(dimension: 'customer_group', start_date: week.first, end_date: week.last)

      within('.page-actions') { expect(page).to have_button('Limpar Filtros', disabled: true) }
    end

    scenario 'enables the button when only the dimension changes' do
      visit freight_billing_path(dimension: 'driver')

      within('.page-actions') { expect(page).to have_link('Limpar Filtros') }
    end
  end

  context 'when an admin user lists the tenants', :admin do
    let!(:admin_user) { create(:admin_user) }

    before { sign_in_admin(admin_user) }

    scenario 'removes the filter on the back office too' do
      visit admin_tenants_path(name: 'Inexistente')

      within('.page-actions') { click_on 'Limpar Filtros' }

      expect(page).to have_current_path(admin_tenants_path)
      within('.page-actions') { expect(page).to have_button('Limpar Filtros', disabled: true) }
    end
  end
end
