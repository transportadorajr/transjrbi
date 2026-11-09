require 'rails_helper'

RSpec.describe Export::Sheet do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:truck) { create(:atua_vehicle, tenant:, plate: 'EXU0F72', manufacture_year: 2021) }
  let!(:trailer) { create(:atua_vehicle, tenant:, plate: 'BEV4G50', manufacture_year: nil) }
  let!(:stranger) { create(:atua_vehicle, tenant: other_tenant, plate: 'ZIZ7D35') }

  describe '#to_h' do
    it 'builds the sheet with the columns of the model and one row per record of the relation, in its order' do
      sheet = described_class.new(name: 'Veículos', relation: tenant.atua_vehicles.order(:plate)).to_h
      plate = sheet[:columns].index { |column| column[:header] == 'Placa' }
      year = sheet[:columns].index { |column| column[:header] == 'Ano de fabricação' }

      expect(Atua::Vehicle.count).to eq(3)
      expect(sheet[:name]).to eq('Veículos')
      expect(sheet[:columns].size).to eq(41)
      expect(sheet[:columns]).to all(include(:header, :type))
      expect(sheet[:rows].map { |row| [row[plate], row[year]] }).to eq([['BEV4G50', nil], ['EXU0F72', 2021]])
      expect(sheet[:rows]).to all(have_attributes(size: 41))
    end

    it 'keeps the header row when the relation is empty' do
      sheet = described_class.new(name: 'Veículos', relation: tenant.atua_vehicles.none).to_h

      expect(sheet[:columns].size).to eq(41)
      expect(sheet[:rows]).to eq([])
    end
  end
end
