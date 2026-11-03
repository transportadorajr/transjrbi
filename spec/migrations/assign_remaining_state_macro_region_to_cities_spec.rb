require 'rails_helper'
require Rails.root.join('db/migrate/20261103142540_assign_remaining_state_macro_region_to_cities')

RSpec.describe AssignRemainingStateMacroRegionToCities do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with cities and documents without a macro region' do
    let!(:tenant) { create(:tenant) }
    let!(:londrina) { create(:city, tenant:, name: 'Londrina', state: 'PR') }
    let!(:londrina_document) { create(:atua_transport_document, tenant:, origin_city: 'LONDRINA', origin_state: 'PR') }
    let!(:maringa_document) { create(:atua_transport_document, tenant:, origin_city: 'MARINGA', origin_state: 'PR') }

    it 'places the cities in the remaining state region and assigns the documents' do
      expect { migration.up }.to change(City, :count).by(1).and change(MacroRegion, :count).by(1)

      resto_parana = tenant.macro_regions.find_by!(name: 'RESTO DO PARANÁ')
      expect(resto_parana.cities.map(&:name)).to contain_exactly('Londrina', 'MARINGA')
      expect([londrina_document, maringa_document].map { |document| document.reload.origin_macro_region }).to eq([resto_parana] * 2)
    end

    it 'can run again without duplicating regions or cities' do
      migration.up

      expect { migration.up }.not_to change { [MacroRegion.count, City.count] }
    end
  end
end
