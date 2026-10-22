require 'rails_helper'

RSpec.describe MacroRegions::AssignCommand do
  let(:tenant) { create(:tenant) }

  context 'with regions and documents of several origins' do
    let!(:vale_do_aco) { create(:macro_region, tenant:) }
    let!(:sao_paulo) { create(:macro_region, :sao_paulo, tenant:) }
    let!(:interior) { create(:macro_region, :interior_sp, tenant:) }
    let!(:ipatinga) { create(:atua_transport_document, tenant:, origin_city: 'IPATINGA', origin_state: 'MG') }
    let!(:cubatao) { create(:atua_transport_document, tenant:, origin_city: 'CUBATAO', origin_state: 'SP') }
    let!(:piracicaba) { create(:atua_transport_document, tenant:, origin_city: 'PIRACICABA', origin_state: 'SP') }
    let!(:juiz_de_fora) { create(:atua_transport_document, tenant:, origin_city: 'JUIZ DE FORA', origin_state: 'MG', origin_macro_region: vale_do_aco) }
    let!(:without_origin) { create(:atua_transport_document, tenant:, origin_city: nil, origin_state: nil) }
    let!(:stranger) { create(:atua_transport_document, origin_city: 'IPATINGA', origin_state: 'MG') }

    it 'assigns every document of the tenant to the region of its origin' do
      expect(described_class.call(tenant)).to eq(4)

      expect(ipatinga.reload.origin_macro_region).to eq(vale_do_aco)
      expect(cubatao.reload.origin_macro_region).to eq(sao_paulo)
      expect(piracicaba.reload.origin_macro_region).to eq(interior)
      expect(juiz_de_fora.reload.origin_macro_region).to be_nil
      expect(without_origin.reload.origin_macro_region).to be_nil
      expect(stranger.reload.origin_macro_region).to be_nil
    end

    it 'does not touch the documents again when nothing changed' do
      described_class.call(tenant)

      expect(described_class.call(tenant)).to eq(0)
    end

    it 'moves the documents when a city changes of region' do
      described_class.call(tenant)
      sao_paulo.update!(cities: ['São Paulo'])

      expect(described_class.call(tenant)).to eq(1)
      expect(cubatao.reload.origin_macro_region).to eq(interior)
    end
  end
end
