require 'rails_helper'
require Rails.root.join('db/migrate/20261028192628_backfill_macro_regions_again')

RSpec.describe BackfillMacroRegionsAgain do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with a tenant without macro regions' do
    let!(:tenant) { create(:tenant) }

    it 'registers the default regions of the tenant' do
      expect { migration.up }.to change(MacroRegion, :count).by(5)

      expect(tenant.macro_regions.order(:name).pluck(:name, :state, :remaining_state)).to eq(
        [
          ['GRANDE BH', 'MG', false],
          ['INTERIOR SP', 'SP', true],
          ['OESTE PARANA', 'PR', false],
          ['SAO PAULO REGIAO METROCAPITAL', 'SP', false],
          ['VALE DO AÇO/MG', 'MG', false],
        ],
      )
      expect(tenant.macro_regions.find_by(name: 'GRANDE BH').cities).to include('Belo Horizonte', 'Contagem', 'Betim')
    end

    it 'assigns the origin macro region of the transport documents' do
      document = create(:atua_transport_document, tenant:, origin_city: 'Contagem', origin_state: 'MG')

      migration.up

      expect(document.reload.origin_macro_region.name).to eq('GRANDE BH')
    end

    it 'can run again without duplicating the regions' do
      migration.up

      expect { migration.up }.not_to change(MacroRegion, :count)
    end
  end

  context 'with a tenant that already has macro regions' do
    let!(:tenant) { create(:tenant) }
    let!(:macro_region) { create(:macro_region, tenant:, name: 'NORTE DE MINAS', state: 'MG') }

    it 'keeps the regions the tenant already has' do
      expect { migration.up }.not_to change(MacroRegion, :count)

      expect(tenant.macro_regions.pluck(:name)).to eq(['NORTE DE MINAS'])
    end
  end
end
