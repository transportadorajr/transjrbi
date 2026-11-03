require 'rails_helper'

RSpec.describe MacroRegions::BackfillCommand do
  let(:tenant) { create(:tenant) }

  context 'without regions' do
    let!(:sabara) { create(:atua_transport_document, tenant:, origin_city: 'SABARA', origin_state: 'MG') }
    let!(:belo_oriente) { create(:atua_transport_document, tenant:, origin_city: 'BELO ORIENTE', origin_state: 'MG') }
    let!(:juiz_de_fora) { create(:atua_transport_document, tenant:, origin_city: 'JUIZ DE FORA', origin_state: 'MG') }
    let!(:corbelia) { create(:atua_transport_document, tenant:, origin_city: 'CORBELIA', origin_state: 'PR') }
    let!(:marialva) { create(:atua_transport_document, tenant:, origin_city: 'MARIALVA', origin_state: 'PR') }
    let!(:curitiba) { create(:atua_transport_document, tenant:, origin_city: 'CURITIBA', origin_state: 'PR') }
    let!(:ponta_grossa) { create(:atua_transport_document, tenant:, origin_city: 'PONTA GROSSA', origin_state: 'PR') }
    let!(:aracariguama) { create(:atua_transport_document, tenant:, origin_city: 'ARACARIGUAMA', origin_state: 'SP') }
    let!(:ourinhos) { create(:atua_transport_document, tenant:, origin_city: 'OURINHOS', origin_state: 'SP') }
    let!(:santa_gertrudes) { create(:atua_transport_document, tenant:, origin_city: 'SANTA GERTRUDES', origin_state: 'SP') }
    let!(:feira_de_santana) { create(:atua_transport_document, tenant:, origin_city: 'FEIRA DE SANTANA', origin_state: 'BA') }
    let!(:campos) { create(:atua_transport_document, tenant:, origin_city: 'CAMPOS DOS GOYTACAZES', origin_state: 'RJ') }

    it 'registers the default regions with their cities' do
      expect { described_class.call(tenant) }.to change(MacroRegion, :count).by(19).and change(City, :count).by(509)

      expect(tenant.macro_regions.order(:id).map { |region| [region.name, region.state, region.cities.count, region.remaining_state] })
        .to eq([['OESTE PARANA', 'PR', 50, false], ['REGIÃO CTBA', 'PR', 35, false], ['SÃO PAULO CAPITAL', 'SP', 41, false],
                ['NORTE PARANA', 'PR', 80, false], ['INTERIOR DE SÃO PAULO', 'SP', 0, true],
                ['PRUDENTE / ASSIS / OURINHOS / SALTO GRANDE / AGUDOS', 'SP', 58, false], ['MINAS GRANDE BH', 'MG', 34, false],
                ['VALE DO AÇO/MG', 'MG', 28, false], ['NORTÃO DE MINAS', 'MG', 54, false], ['REGIÃO DE JUIZ DE FORA', 'MG', 33, false],
                ['REGIÃO UBERLANDIA E UBERABA', 'MG', 37, false], ['BAHIA', 'BA', 0, true], ['RIO DE JANEIRO CAPITAL', 'RJ', 22, false],
                ['CAMPOS GOYTACAZES E INTERIOR', 'RJ', 0, true], ['ESPIRITO SANTO', 'ES', 0, true], ['SUDOESTE PARANAENSE', 'PR', 37, false],
                ['GOIANIA', 'GO', 0, true], ['CUIABA MT', 'MT', 0, true], ['SANTA CATARINA', 'SC', 0, true]])
    end

    it 'assigns the documents to the regions of their cities' do
      described_class.call(tenant)

      documents = [sabara, belo_oriente, juiz_de_fora, corbelia, marialva, curitiba, ponta_grossa, aracariguama, ourinhos, santa_gertrudes,
                   feira_de_santana, campos]
      expect(documents.map { |document| document.reload.origin_macro_region&.name })
        .to eq(['MINAS GRANDE BH', 'VALE DO AÇO/MG', 'REGIÃO DE JUIZ DE FORA', 'OESTE PARANA', 'NORTE PARANA', 'REGIÃO CTBA', nil,
                'SÃO PAULO CAPITAL', 'PRUDENTE / ASSIS / OURINHOS / SALTO GRANDE / AGUDOS', 'INTERIOR DE SÃO PAULO', 'BAHIA',
                'CAMPOS GOYTACAZES E INTERIOR'])
    end

    it 'can run again without duplicating regions or cities' do
      described_class.call(tenant)

      expect { described_class.call(tenant) }.not_to change { [MacroRegion.count, City.count] }
    end
  end

  context 'when the tenant already has regions' do
    let!(:grande_bh) { create(:macro_region, tenant:, name: 'GRANDE BH', city_names: ['Belo Horizonte', 'Sete Lagoas']) }
    let!(:interior) { create(:macro_region, :interior_sp, tenant:, name: 'RESTANTE SP') }
    let!(:vale_do_aco) { create(:macro_region, tenant:, name: 'LESTE MG', city_names: ['Ipatinga']) }
    let!(:betim) { create(:city, tenant:, name: 'BETIM', state: 'MG', macro_region: vale_do_aco) }
    let!(:contagem) { create(:city, tenant:, name: 'Contagem', state: 'MG') }

    it 'renames the existing regions and keeps the cities the tenant already organized' do
      expect { described_class.call(tenant) }.to change(MacroRegion, :count).by(17)

      expect(grande_bh.reload.name).to eq('MINAS GRANDE BH')
      expect(interior.reload).to have_attributes(name: 'INTERIOR DE SÃO PAULO', remaining_state: true)
      expect(grande_bh.cities.pluck(:name)).to include('Belo Horizonte', 'Sete Lagoas', 'Contagem', 'Sabará')
      expect(betim.reload.macro_region).to eq(vale_do_aco)
      expect(contagem.reload.macro_region).to eq(grande_bh)
      expect(tenant.macro_regions.find_by(name: 'VALE DO AÇO/MG').cities.pluck(:name)).not_to include('Ipatinga')
    end
  end

  context 'when a default city sits in the remaining state region' do
    let!(:resto_minas) { create(:macro_region, tenant:, name: 'RESTO DE MINAS GERAIS', remaining_state: true, city_names: []) }
    let!(:sabara) { create(:city, tenant:, name: 'Sabará', state: 'MG', macro_region: resto_minas) }
    let!(:unlisted) { create(:city, tenant:, name: 'Patos de Minas', state: 'MG') }

    it 'moves the default city to its region and keeps the other cities in the remaining state region' do
      described_class.call(tenant)

      expect(sabara.reload.macro_region.name).to eq('MINAS GRANDE BH')
      expect(unlisted.reload.macro_region).to eq(resto_minas)
    end
  end
end
