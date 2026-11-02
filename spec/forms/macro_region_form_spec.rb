require 'rails_helper'

RSpec.describe MacroRegionForm do
  let(:tenant) { create(:tenant) }

  describe '#save' do
    let!(:ipatinga) { create(:city, tenant:, name: 'Ipatinga', state: 'MG') }
    let!(:timoteo) { create(:city, tenant:, name: 'Timóteo', state: 'MG') }
    let!(:ipatinga_document) { create(:atua_transport_document, tenant:, origin_city: 'IPATINGA', origin_state: 'MG') }

    it 'creates a region with the selected cities and assigns the documents of its cities' do
      form = described_class.new(tenant:, name: ' VALE DO AÇO/MG ', state: 'mg', city_ids: ['', ipatinga.id.to_s, timoteo.id.to_s, ipatinga.id.to_s])

      expect { expect(form.save).to be(true) }.to change(MacroRegion, :count).by(1)

      region = MacroRegion.last
      expect(region).to have_attributes(tenant:, name: 'VALE DO AÇO/MG', state: 'MG', remaining_state: false)
      expect(region.cities).to contain_exactly(ipatinga, timoteo)
      expect(ipatinga_document.reload.origin_macro_region).to eq(region)
    end

    it 'ignores the cities of a remaining state region' do
      form = described_class.new(tenant:, name: 'INTERIOR MG', state: 'MG', city_ids: [ipatinga.id], remaining_state: '1')

      expect(form.save).to be(true)
      expect(MacroRegion.last).to have_attributes(remaining_state: true)
      expect(MacroRegion.last.cities).to be_empty
      expect(ipatinga_document.reload.origin_macro_region).to eq(MacroRegion.last)
    end

    it 'rejects a region without the required fields' do
      form = described_class.new(tenant:, state: 'Minas')

      expect { expect(form.save).to be_falsey }.not_to change(MacroRegion, :count)
      expect(form.errors.full_messages).to contain_exactly('Nome não pode ficar em branco', 'UF não é válido',
                                                           'Cidades não pode ficar em branco')
    end

    it 'rejects cities of another state' do
      form = described_class.new(tenant:, name: 'LESTE SP', state: 'SP', city_ids: [ipatinga.id])

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Cidades Ipatinga não são da UF SP'])
    end

    it 'ignores the cities of another tenant' do
      stranger_city = create(:city, tenant: create(:tenant), name: 'Ipatinga', state: 'MG')
      form = described_class.new(tenant:, name: 'VALE DO AÇO/MG', state: 'MG', city_ids: [stranger_city.id])

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Cidades não pode ficar em branco'])
      expect(stranger_city.reload.macro_region).to be_nil
    end

    context 'with other regions of the tenant' do
      let!(:vale_do_aco) { create(:macro_region, tenant:, city_names: []) }
      let!(:interior) { create(:macro_region, :interior_sp, tenant:) }
      let!(:belo_oriente) { create(:city, tenant:, name: 'Belo Oriente', state: 'MG') }

      before do
        vale_do_aco.cities = [ipatinga, timoteo]
        create(:macro_region, :interior_sp, tenant: create(:tenant), name: 'GRANDE BH')
      end

      it 'rejects a name already in use by the tenant' do
        form = described_class.new(tenant:, name: 'VALE DO AÇO/MG', state: 'MG', city_ids: [belo_oriente.id])

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to eq(['Nome já está em uso por outra macro região'])
      end

      it 'rejects a second remaining state region in the same state' do
        form = described_class.new(tenant:, name: 'RESTANTE SP', state: 'SP', remaining_state: true)

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to eq(['Abrange o restante do estado já está em outra macro região desta UF'])
      end

      it 'rejects cities already in another region' do
        form = described_class.new(tenant:, name: 'LESTE MG', state: 'MG', city_ids: [ipatinga.id, timoteo.id, belo_oriente.id])

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to eq(['Cidades Ipatinga e Timóteo já estão em outra macro região desta UF'])
      end

      it 'offers only the cities without a region and the cities of the region itself' do
        expect(described_class.new(tenant:).available_cities).to eq([belo_oriente])
        expect(described_class.for_macro_region(vale_do_aco).available_cities).to eq([belo_oriente, ipatinga, timoteo])
      end

      it 'updates the region adding and removing cities' do
        form = described_class.for_macro_region(vale_do_aco)
        form.assign_attributes(city_ids: [ipatinga.id, belo_oriente.id])

        expect { expect(form.save).to be(true) }.not_to change(MacroRegion, :count)
        expect(vale_do_aco.reload.cities).to contain_exactly(ipatinga, belo_oriente)
        expect(timoteo.reload.macro_region).to be_nil
        expect(City.count).to eq(3)
      end
    end
  end
end
