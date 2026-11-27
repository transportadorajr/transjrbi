require 'rails_helper'

describe 'Pagination' do
  let!(:tenant) { create(:tenant) }
  let!(:owner) { create(:user, tenant:, user_type: :owner) }

  before { login_as(owner, scope: :user) }

  context 'with a listing longer than one page', :js do
    let!(:resource) { create(:resource, name: 'Macrorregiões', slug: 'macro_regions') }

    before do
      allow(Kaminari.config).to receive(:default_per_page).and_return(25)
      50.times { |index| create(:macro_region, tenant:, name: format('Região %02d', index + 1), state: 'MG', city_names: []) }
    end

    def region_names(range)
      range.map { |number| format('Região %02d', number) }
    end

    def table_card_top
      page.evaluate_script("document.querySelector('.table-card').getBoundingClientRect().top")
    end

    def expect_table_card_in_view
      page.document.synchronize do
        raise Capybara::ExpectationNotMet, 'table card is not at the top of the screen' unless table_card_top.between?(0, 120)
      end
      expect(page.evaluate_script('window.scrollY')).to be > 0
    end

    scenario 'keeps the table in view when going to the next page' do
      visit macro_regions_path(sort: 'name')
      expect(page).to have_link('Região 01')

      within('.table-pagination') { click_on '2' }

      expect(page).to have_current_path(/page=2/)
      expect(html_table_to_rows).to eq(
        [%w[NOME UF ABRANGÊNCIA STATUS AÇÕES]] + region_names(26..50).map { |name| [name, 'MG', '0 cidades', 'Ativa', ''] },
      )
      expect(MacroRegion.where(tenant:).count).to eq(50)
      expect_table_card_in_view
    end

    scenario 'keeps the table in view when going to the next page on a phone' do
      use_mobile_screen
      visit macro_regions_path(sort: 'name')
      expect(page).to have_link('Região 01')

      within('.table-pagination') { click_on '2' }

      expect(page).to have_current_path(/page=2/)
      expect(html_table_to_rows).to eq(
        [%w[NOME UF STATUS AÇÕES]] + region_names(26..50).map { |name| [name, 'MG', 'Ativa', 'Opções'] },
      )
      expect(MacroRegion.where(tenant:).count).to eq(50)
      expect_table_card_in_view
    end
  end
end
