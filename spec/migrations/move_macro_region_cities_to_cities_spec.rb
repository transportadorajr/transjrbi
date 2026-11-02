require 'rails_helper'
require Rails.root.join('db/migrate/20261102201939_move_macro_region_cities_to_cities')

RSpec.describe MoveMacroRegionCitiesToCities do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  let!(:tenant) { create(:tenant) }
  let!(:vale_do_aco) { create(:macro_region, tenant:, city_names: %w[Ipatinga Timóteo]) }
  let!(:interior) { create(:macro_region, :interior_sp, tenant:) }

  after do
    MacroRegion.reset_column_information
    migration.up if MacroRegion.connection.column_exists?(:macro_regions, :cities)
    MacroRegion.reset_column_information
  end

  it 'moves the cities back to the region list when rolling back and into the cities table again' do
    migration.down
    MacroRegion.reset_column_information

    expect(City.count).to eq(0)
    expect(vale_do_aco.reload.read_attribute(:cities)).to eq(%w[Ipatinga Timóteo])
    expect(interior.reload.read_attribute(:cities)).to eq([])

    migration.up
    MacroRegion.reset_column_information

    expect(MacroRegion.column_names).not_to include('cities')
    expect(City.order(:name).pluck(:tenant_id, :macro_region_id, :name, :state))
      .to eq([[tenant.id, vale_do_aco.id, 'Ipatinga', 'MG'], [tenant.id, vale_do_aco.id, 'Timóteo', 'MG']])
  end
end
