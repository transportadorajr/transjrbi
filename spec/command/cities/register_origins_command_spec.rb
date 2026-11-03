require 'rails_helper'

RSpec.describe Cities::RegisterOriginsCommand do
  let(:tenant) { create(:tenant) }

  context 'with documents from cities in and out of the registered ones' do
    let!(:oeste_parana) { create(:macro_region, tenant:, name: 'OESTE PARANA', state: 'PR', city_names: ['Corbélia']) }
    let!(:corbelia_document) { create(:atua_transport_document, tenant:, origin_city: 'CORBELIA', origin_state: 'PR') }
    let!(:londrina_document) { create(:atua_transport_document, tenant:, origin_city: ' LONDRINA ', origin_state: 'pr') }
    let!(:other_londrina_document) { create(:atua_transport_document, tenant:, origin_city: 'Londrina', origin_state: 'PR') }
    let!(:foreign_document) { create(:atua_transport_document, tenant:, origin_city: 'BUENOS AIRES', origin_state: 'EX') }
    let!(:stranger_document) { create(:atua_transport_document, tenant: create(:tenant), origin_city: 'MARINGA', origin_state: 'PR') }

    it 'registers the new origin cities in the remaining state region of their state' do
      expect { described_class.call(tenant) }.to change(City, :count).by(1).and change(MacroRegion, :count).by(1)

      city = tenant.cities.find_by!(name: 'LONDRINA')
      expect(city).to have_attributes(state: 'PR')
      expect(city.macro_region).to have_attributes(name: 'RESTO DO PARANÁ', state: 'PR', remaining_state: true)
      expect(oeste_parana.cities.map(&:name)).to eq(['Corbélia'])
    end

    it 'does not register foreign cities or cities of another tenant' do
      described_class.call(tenant)

      expect(tenant.cities.where(state: 'EX')).to be_empty
      expect(City.where(name: 'MARINGA')).to be_empty
    end

    it 'can run again without duplicating cities' do
      described_class.call(tenant)

      expect { expect(described_class.call(tenant)).to be_empty }.not_to change { [City.count, MacroRegion.count] }
    end
  end
end
