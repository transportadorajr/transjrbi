require 'rails_helper'

RSpec.describe Atua::MapVehiclesCommand do
  let(:tenant) { build(:tenant) }
  let(:spreadsheet) { read_atua_fixture(:vehicles) }
  let(:vehicles) { described_class.call(tenant, spreadsheet) }

  def vehicle(code)
    vehicles.find { |attributes| attributes[:code] == code }
  end

  describe '.call' do
    it 'maps one record per row with unique codes and plates' do
      expect(vehicles.size).to eq(1391)
      expect(vehicles.pluck(:code).uniq.size).to eq(1391)
      expect(vehicles.pluck(:plate).uniq.size).to eq(1391)
    end

    it 'maps every attribute of a vehicle' do
      expect(vehicle(152).except(:raw_data)).to eq(
        code: 152, plate: 'DTF0986', category: 'Carreta', vehicle_kind: 'CARRETA GRADE BAIXA TRUCADA', vehicle_kind_code: 25,
        wheelset: 'Utilitário', body: 'Aberta', brand_code: 39, brand: 'GUERRA', model: '1234',
        manufacture_year: 1994, model_year: 1994, renavam: '54559603157', chassis: nil, color: 'PRETA',
        ownership: 'Terceiro', owner_code: 240, owner_name: 'PESSOA 04447',
        owner_document: '47.320.631/0001-51', owner_document_digits: '47320631000151', antt: '3952695',
        driver_code: nil, driver_name: nil, driver_document: nil, driver_document_digits: nil, driver_license: nil,
        risk_status: 'Vencido', data_expires_on: Date.new(2015, 11, 21),
        source_updated_at: Time.zone.local(2015, 5, 25, 15, 41, 45), status: 'Normal',
        city_code: 2895, city: 'CASCAVEL', state_code: 18, state: 'PR',
        owner_whatsapp_at: nil, driver_whatsapp_at: nil, high_performance_at: nil,
        registered_month_on: Date.new(2015, 4, 1), updated_month_on: Date.new(2015, 5, 1)
      )
      expect(vehicle(152)[:raw_data]).to eq(spreadsheet.rows.first)
    end

    it 'pads the renavam that came as a number and keeps the one that came as text' do
      numeric, text = vehicles.select { |attributes| attributes[:renavam] }.partition { |attributes| attributes[:raw_data]['nr_renavam'].is_a?(Float) }

      expect(numeric.pluck(:renavam)).to all(match(/\A\d{11}\z/))
      expect(text.pluck(:renavam)).to eq(text.map { |attributes| attributes[:raw_data]['nr_renavam'].strip })
    end

    it 'turns the whatsapp flag of the owner into a datetime' do
      expect(vehicles.count { |attributes| attributes[:owner_whatsapp_at] }).to eq(374)
    end

    context 'when a required column is missing' do
      let(:spreadsheet) do
        fixture = read_atua_fixture(:vehicles)
        atua_spreadsheet(headers: fixture.headers - %w[ds_placa], rows: fixture.rows.first(1))
      end

      it 'raises a layout error naming the missing and the received columns' do
        expect { vehicles }.to raise_error(
          Atua::LayoutError,
          /\AO relatório rel_veiculo_terceiro_detalhado veio sem as colunas obrigatórias ds_placa\. Colunas recebidas: nm_pessoa, id_atualizado/,
        )
      end
    end
  end
end
