require 'rails_helper'

RSpec.describe PaginationHelper do
  it 'renders the current page without a link, so clicking it does not jump to the top of the screen' do
    page = instance_double(Kaminari::Helpers::Paginator::PageProxy, current?: true, to_s: '2')
    item = Capybara.string(helper.pagination_page_item(page, '/macro_regions?page=2', false))

    expect(item).to have_css('li.page-item.active span.page-link[aria-current="page"]', text: '2')
    expect(item).to have_no_css('a')
  end

  it 'renders the other pages as links to their url' do
    page = instance_double(Kaminari::Helpers::Paginator::PageProxy, current?: false, to_s: '3', rel: nil)
    item = Capybara.string(helper.pagination_page_item(page, '/macro_regions?page=3', false))

    expect(item.find('li.page-item a.page-link', text: '3')[:href]).to eq('/macro_regions?page=3')
  end
end
