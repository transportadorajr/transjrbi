require 'rails_helper'
require Rails.root.join('db/migrate/20261028192628_backfill_macro_regions_again')

RSpec.describe BackfillMacroRegionsAgain do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with a tenant without macro regions' do
    let!(:tenant) { create(:tenant) }

    it 'registers the default regions of the tenant' do
      expect { migration.up }.to change(MacroRegion, :count).by(19)

      expect(tenant.macro_regions.where(state: %w[MG SP]).order(:state, :name).pluck(:name, :state, :remaining_state)).to eq(
        [
          ['MINAS GRANDE BH', 'MG', false],
          ['NORTÃO DE MINAS', 'MG', false],
          ['REGIÃO DE JUIZ DE FORA', 'MG', false],
          ['REGIÃO UBERLANDIA E UBERABA', 'MG', false],
          ['VALE DO AÇO/MG', 'MG', false],
          ['INTERIOR DE SÃO PAULO', 'SP', true],
          ['PRUDENTE / ASSIS / OURINHOS / SALTO GRANDE / AGUDOS', 'SP', false],
          ['SÃO PAULO CAPITAL', 'SP', false],
        ],
      )
      expect(tenant.macro_regions.find_by(name: 'MINAS GRANDE BH').cities.pluck(:name)).to include('Belo Horizonte', 'Contagem', 'Betim')
    end

    it 'assigns the origin macro region of the transport documents' do
      document = create(:atua_transport_document, tenant:, origin_city: 'Contagem', origin_state: 'MG')

      migration.up

      expect(document.reload.origin_macro_region.name).to eq('MINAS GRANDE BH')
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
      expect { migration.up }.to change(MacroRegion, :count).by(19)

      expect(macro_region.reload).to have_attributes(name: 'NORTE DE MINAS', state: 'MG')
      expect(macro_region.cities.pluck(:name)).to contain_exactly('Ipatinga', 'Coronel Fabriciano', 'Timóteo')
    end
  end
end
