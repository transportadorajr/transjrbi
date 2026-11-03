require 'rails_helper'

RSpec.describe CityForm do
  let(:tenant) { create(:tenant) }
  let!(:vale_do_aco) { create(:macro_region, tenant:, city_names: ['Timóteo']) }
  let!(:interior) { create(:macro_region, :interior_sp, tenant:) }
  let!(:ipatinga_document) { create(:atua_transport_document, tenant:, origin_city: 'IPATINGA', origin_state: 'MG') }

  describe '#save' do
    it 'creates a city in a macro region and assigns the documents of the city' do
      form = described_class.new(tenant:, name: ' Ipatinga ', state: 'mg', macro_region_id: vale_do_aco.id)

      expect { expect(form.save).to be(true) }.to change(City, :count).by(1)

      city = City.last
      expect(city).to have_attributes(tenant:, name: 'Ipatinga', state: 'MG', macro_region: vale_do_aco)
      expect(ipatinga_document.reload.origin_macro_region).to eq(vale_do_aco)
    end

    it 'places a city without a macro region in a new remaining state region of its state' do
      form = described_class.new(tenant:, name: 'Ipatinga', state: 'MG', macro_region_id: '')

      expect { expect(form.save).to be(true) }.to change(MacroRegion, :count).by(1)

      region = MacroRegion.last
      expect(region).to have_attributes(tenant:, name: 'RESTO DE MINAS GERAIS', state: 'MG', remaining_state: true)
      expect(City.last.macro_region).to eq(region)
      expect(ipatinga_document.reload.origin_macro_region).to eq(region)
    end

    it 'places a city without a macro region in the remaining state region the tenant already has' do
      form = described_class.new(tenant:, name: 'Cubatão', state: 'SP')

      expect { expect(form.save).to be(true) }.not_to change(MacroRegion, :count)
      expect(City.last.macro_region).to eq(interior)
    end

    it 'leaves a foreign city without a macro region' do
      form = described_class.new(tenant:, name: 'Buenos Aires', state: 'EX')

      expect { expect(form.save).to be(true) }.not_to change(MacroRegion, :count)
      expect(City.last.macro_region).to be_nil
    end

    it 'rejects a city without the required fields' do
      form = described_class.new(tenant:, state: 'Minas')

      expect { expect(form.save).to be_falsey }.not_to change(City, :count)
      expect(form.errors.full_messages).to contain_exactly('Nome não pode ficar em branco', 'UF não é válido')
    end

    it 'rejects a city already registered in the state ignoring accents and case' do
      form = described_class.new(tenant:, name: 'TIMOTEO', state: 'MG')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Nome já está cadastrada nesta UF'])
    end

    it 'accepts a city of the same name in another state' do
      expect(described_class.new(tenant:, name: 'Timóteo', state: 'SP').save).to be(true)
    end

    it 'rejects a macro region of another state' do
      form = described_class.new(tenant:, name: 'Cubatão', state: 'SP', macro_region_id: vale_do_aco.id)

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Macro região é de outra UF (MG)'])
    end

    it 'rejects a remaining state region or a region of another tenant' do
      stranger_region = create(:macro_region, tenant: create(:tenant), city_names: [])

      expect(described_class.new(tenant:, name: 'Cubatão', state: 'SP', macro_region_id: interior.id).save).to be_falsey
      form = described_class.new(tenant:, name: 'Ipatinga', state: 'MG', macro_region_id: stranger_region.id)

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Macro região não é válido'])
    end

    it 'updates the city moving its documents to the remaining state region' do
      city = create(:city, tenant:, name: 'Cubatão', state: 'SP')
      document = create(:atua_transport_document, tenant:, origin_city: 'CUBATAO', origin_state: 'SP')
      form = described_class.for_city(city)
      form.assign_attributes(name: 'Cubatão')

      expect { expect(form.save).to be(true) }.not_to change(City, :count)
      expect(city.reload.macro_region).to eq(interior)
      expect(document.reload.origin_macro_region).to eq(interior)
    end

    it 'keeps its own name when updating' do
      form = described_class.for_city(vale_do_aco.cities.first)
      form.assign_attributes(macro_region_id: nil)

      expect(form.save).to be(true)
      expect(City.find_by(name: 'Timóteo').macro_region.name).to eq('RESTO DE MINAS GERAIS')
    end
  end

  describe '#available_macro_regions' do
    it 'offers only the regions that list cities' do
      expect(described_class.new(tenant:).available_macro_regions).to eq([vale_do_aco])
    end
  end
end
