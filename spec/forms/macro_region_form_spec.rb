require 'rails_helper'

RSpec.describe MacroRegionForm do
  let(:tenant) { create(:tenant) }

  describe '#save' do
    let!(:ipatinga_document) { create(:atua_transport_document, tenant:, origin_city: 'IPATINGA', origin_state: 'MG') }

    it 'creates a region with one city per line and assigns the documents of its cities' do
      form = described_class.new(tenant:, name: ' VALE DO AÇO/MG ', state: 'mg', cities: "Ipatinga\n timóteo \n\nTIMOTEO")

      expect { expect(form.save).to be(true) }.to change(MacroRegion, :count).by(1)

      region = MacroRegion.last
      expect(region).to have_attributes(tenant:, name: 'VALE DO AÇO/MG', state: 'MG', cities: %w[Ipatinga timóteo],
                                        remaining_state: false)
      expect(ipatinga_document.reload.origin_macro_region).to eq(region)
    end

    it 'ignores the cities of a remaining state region' do
      form = described_class.new(tenant:, name: 'INTERIOR MG', state: 'MG', cities: 'Ipatinga', remaining_state: '1')

      expect(form.save).to be(true)
      expect(MacroRegion.last).to have_attributes(cities: [], remaining_state: true)
      expect(ipatinga_document.reload.origin_macro_region).to eq(MacroRegion.last)
    end

    it 'rejects a region without the required fields' do
      form = described_class.new(tenant:, state: 'Minas')

      expect { expect(form.save).to be_falsey }.not_to change(MacroRegion, :count)
      expect(form.errors.full_messages).to contain_exactly('Nome não pode ficar em branco', 'UF não é válido',
                                                           'Cidades não pode ficar em branco')
    end

    context 'with other regions of the tenant' do
      let!(:vale_do_aco) { create(:macro_region, tenant:) }
      let!(:interior) { create(:macro_region, :interior_sp, tenant:) }

      before { create(:macro_region, :interior_sp, tenant: create(:tenant), name: 'GRANDE BH') }

      it 'rejects a name already in use by the tenant' do
        form = described_class.new(tenant:, name: 'VALE DO AÇO/MG', state: 'ES', cities: 'Serra')

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to eq(['Nome já está em uso por outra macro região'])
      end

      it 'rejects a second remaining state region in the same state' do
        form = described_class.new(tenant:, name: 'RESTANTE SP', state: 'SP', remaining_state: true)

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to eq(['Abrange o restante do estado já está em outra macro região desta UF'])
      end

      it 'rejects cities already listed in another region of the same state' do
        form = described_class.new(tenant:, name: 'LESTE MG', state: 'MG', cities: "IPATINGA\nTimoteo\nGovernador Valadares")

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to eq(['Cidades IPATINGA e Timoteo já estão em outra macro região desta UF'])
      end

      it 'accepts a city of the same name in another state' do
        form = described_class.new(tenant:, name: 'IPATINGA SP', state: 'SP', cities: 'Ipatinga')

        expect(form.save).to be(true)
      end

      it 'updates the region keeping its own cities and name' do
        form = described_class.for_macro_region(vale_do_aco)
        form.assign_attributes(cities: "Ipatinga\nTimóteo\nCoronel Fabriciano\nBelo Oriente")

        expect { expect(form.save).to be(true) }.not_to change(MacroRegion, :count)
        expect(vale_do_aco.reload.cities).to eq(['Ipatinga', 'Timóteo', 'Coronel Fabriciano', 'Belo Oriente'])
      end
    end
  end
end
