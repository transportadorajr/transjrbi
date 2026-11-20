require 'rails_helper'

RSpec.describe SortingHelper do
  before do
    helper.request.path = '/freight_billing/freights'
    helper.request.query_string = 'key=7&sort=gross&direction=asc&freights_sort=gross_per_km&freights_direction=desc'
    helper.params.merge!(key: '7', sort: 'gross', direction: 'asc', freights_sort: 'gross_per_km', freights_direction: 'desc')
  end

  it 'reads the sort of a scoped table from its own parameters, keeping the others' do
    header = Capybara.string(helper.sortable_header('Bruto/km', :gross_per_km, first_direction: :desc, scope: 'freights', frame: 'freights_frame'))
    link = header.find('a')

    expect(header).to have_css('th[aria-sort="descending"]')
    expect(Rack::Utils.parse_query(URI(link[:href]).query))
      .to eq('key' => '7', 'sort' => 'gross', 'direction' => 'asc', 'freights_sort' => 'gross_per_km', 'freights_direction' => 'asc')
    expect(link['data-turbo-frame']).to eq('freights_frame')
  end

  it 'keeps reading the unscoped sort from the sort and direction parameters' do
    header = Capybara.string(helper.sortable_header('Frete bruto', :gross))

    expect(header).to have_css('th[aria-sort="ascending"]')
    expect(Rack::Utils.parse_query(URI(header.find('a')[:href]).query)).to include('sort' => 'gross', 'direction' => 'desc')
    expect(header.find('a')['data-turbo-frame']).to be_nil
  end

  it 'starts a scoped column that is not sorted yet in its first direction' do
    header = Capybara.string(helper.sortable_header('Frete líquido', :net, first_direction: :desc, scope: 'freights'))

    expect(header).to have_no_css('th[aria-sort]')
    expect(Rack::Utils.parse_query(URI(header.find('a')[:href]).query)).to include('freights_sort' => 'net', 'freights_direction' => 'desc')
  end
end
