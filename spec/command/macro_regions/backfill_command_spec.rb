require 'rails_helper'

RSpec.describe MacroRegions::BackfillCommand do
  let(:tenant) { create(:tenant) }

  context 'without regions' do
    let!(:sabara) { create(:atua_transport_document, tenant:, origin_city: 'SABARA', origin_state: 'MG') }
    let!(:belo_oriente) { create(:atua_transport_document, tenant:, origin_city: 'BELO ORIENTE', origin_state: 'MG') }
    let!(:corbelia) { create(:atua_transport_document, tenant:, origin_city: 'CORBELIA', origin_state: 'PR') }
    let!(:aracariguama) { create(:atua_transport_document, tenant:, origin_city: 'ARACARIGUAMA', origin_state: 'SP') }
    let!(:santa_gertrudes) { create(:atua_transport_document, tenant:, origin_city: 'SANTA GERTRUDES', origin_state: 'SP') }
    let!(:marialva) { create(:atua_transport_document, tenant:, origin_city: 'MARIALVA', origin_state: 'PR') }

    it 'registers the default regions and assigns the documents' do
      expect { described_class.call(tenant) }.to change(MacroRegion, :count).by(5)

      expect(tenant.macro_regions.order(:id).map { |region| [region.name, region.state, region.cities.size, region.remaining_state] })
        .to eq([['GRANDE BH', 'MG', 34, false], ['VALE DO AÇO/MG', 'MG', 28, false], ['OESTE PARANA', 'PR', 50, false],
                ['SAO PAULO REGIAO METROCAPITAL', 'SP', 41, false], ['INTERIOR SP', 'SP', 0, true]])
      expect([sabara, belo_oriente, corbelia, aracariguama, santa_gertrudes, marialva].map { |document| document.reload.origin_macro_region&.name })
        .to eq(['GRANDE BH', 'VALE DO AÇO/MG', 'OESTE PARANA', 'SAO PAULO REGIAO METROCAPITAL', 'INTERIOR SP', nil])
    end
  end

  context 'when the tenant already has regions' do
    let!(:region) { create(:macro_region, tenant:) }

    it 'keeps the regions of the tenant' do
      expect { expect(described_class.call(tenant)).to eq([region]) }.not_to change(MacroRegion, :count)
    end
  end
end
