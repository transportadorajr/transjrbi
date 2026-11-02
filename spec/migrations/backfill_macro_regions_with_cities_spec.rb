require 'rails_helper'
require Rails.root.join('db/migrate/20261102201941_backfill_macro_regions_with_cities')

RSpec.describe BackfillMacroRegionsWithCities do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with a tenant that already has the first default regions' do
    let!(:tenant) { create(:tenant) }
    let!(:grande_bh) { create(:macro_region, tenant:, name: 'GRANDE BH', city_names: ['Belo Horizonte']) }
    let!(:document) { create(:atua_transport_document, tenant:, origin_city: 'JUIZ DE FORA', origin_state: 'MG') }

    it 'creates the missing regions, renames the existing ones and assigns the documents' do
      expect { migration.up }.to change(MacroRegion, :count).by(18)

      expect(grande_bh.reload.name).to eq('MINAS GRANDE BH')
      expect(grande_bh.cities.count).to eq(34)
      expect(document.reload.origin_macro_region.name).to eq('REGIÃO DE JUIZ DE FORA')
    end

    it 'can run again without duplicating regions or cities' do
      migration.up

      expect { migration.up }.not_to change { [MacroRegion.count, City.count] }
    end
  end
end
