require 'rails_helper'

describe 'Clearing the applied filters' do
  let!(:tenant) { create(:tenant) }
  let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

  before { login_as(admin, scope: :user) }

  context 'when listing the macro regions' do
    let!(:resource) { create(:resource, name: 'Macrorregiões', slug: 'macro_regions') }
    let!(:santos) { create(:macro_region, tenant:, name: 'Santos', state: 'SP') }
    let!(:betim) { create(:macro_region, tenant:, name: 'Betim', state: 'MG') }

    scenario 'hides the button while no filter is applied' do
      visit macro_regions_path

      expect(page).to have_link(href: '#filtersModal')
      expect(page).to have_no_link('Limpar', exact: true)
    end

    scenario 'hides the button when only the sort and the page are in the URL' do
      visit macro_regions_path(sort: 'name', direction: 'desc', page: 1)

      expect(page).to have_link(href: '#filtersModal')
      expect(page).to have_no_link('Limpar', exact: true)
    end

    scenario 'hides the button when the filters were submitted blank' do
      visit macro_regions_path(name: '')

      expect(page).to have_link(href: '#filtersModal')
      expect(page).to have_no_link('Limpar', exact: true)
    end

    scenario 'removes every filter with one click' do
      visit macro_regions_path(name: 'Santos')

      expect(MacroRegion.count).to eq(2)
      expect(html_table_to_rows.drop(1).map(&:first)).to eq(['Santos'])

      click_on 'Limpar', exact: true

      expect(page).to have_current_path(macro_regions_path)
      expect(html_table_to_rows.drop(1).map(&:first)).to eq(%w[Betim Santos])
      expect(page).to have_no_link('Limpar', exact: true)
    end

    scenario 'fits a phone screen next to the filters button', :js do
      use_mobile_screen
      visit macro_regions_path(name: 'Santos')

      expect(page).to have_link('Limpar', exact: true)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end

  context 'when viewing the freight billing' do
    let!(:resource) { create(:resource, name: 'Faturamento de fretes', slug: 'freight_billing', writable: false) }

    scenario 'keeps the selected dimension, which is not a filter' do
      visit freight_billing_path(dimension: 'driver', plate: 'ABC1D23')

      click_on 'Limpar', exact: true

      expect(page).to have_current_path(freight_billing_path(dimension: 'driver'))
      expect(page).to have_no_link('Limpar', exact: true)
    end
  end

  context 'when an admin user lists the tenants', :admin do
    let!(:admin_user) { create(:admin_user) }

    before { sign_in_admin(admin_user) }

    scenario 'removes the filter on the back office too' do
      visit admin_tenants_path(name: 'Inexistente')

      click_on 'Limpar', exact: true

      expect(page).to have_current_path(admin_tenants_path)
      expect(page).to have_no_link('Limpar', exact: true)
    end
  end
end
