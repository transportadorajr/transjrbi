require 'rails_helper'

RSpec.describe Atua::MapCustomersCommand do
  let(:tenant) { build(:tenant) }
  let(:spreadsheet) { read_atua_fixture(:customers) }
  let(:now) { Time.zone.local(2026, 10, 13, 10, 0) }
  let(:previous) { {} }
  let(:customers) { travel_to(now) { described_class.call(tenant, spreadsheet, previous:) } }

  def customer(code)
    customers.find { |attributes| attributes[:code] == code }
  end

  describe '.call' do
    it 'maps one record per row' do
      expect(customers.size).to eq(4833)
    end

    it 'maps every attribute of a customer' do
      expect(customer(294).except(:raw_data)).to eq(
        code: 294, name: 'PESSOA 00001', trade_name: 'PESSOA 00001', person_kind: 'Pessoa Jurídica',
        document: '50.434.224/0001-80', document_digits: '50434224000180', state_registration: '303980098',
        street: 'RUA ANONIMA 0001', complement: nil, district: 'BAIRRO 0001', zip_code: '34619075',
        city_code: 1605, city: 'TRES LAGOAS', state_code: 14, state: 'MS',
        phone: '(00)1628-9660', emails: [], activity: 'OUTROS', payment_method: nil, payment_term: nil,
        registered_on: Date.new(2015, 4, 13), last_billed_on: nil, status: 'Normal',
        whatsapp_at: nil, exporter_at: now, simples_optant_at: nil, updated_month_on: Date.new(2024, 10, 1)
      )
      expect(customer(294)[:raw_data]).to eq(spreadsheet.rows.first)
    end

    it 'builds the update month from a month in text or in number' do
      months = spreadsheet.rows.pluck('dt_mes_atualizacao')

      expect(months).to include(a_kind_of(String), a_kind_of(Float))
      expect(customers.pluck(:updated_month_on)).to all(satisfy { |date| date.day == 1 })
    end

    it 'uses the date of the consultation for the simples optant flag' do
      simples = customers.select { |attributes| attributes[:raw_data]['id_optante_simples'] == 'SIM' }

      consulted, not_consulted = simples.partition { |attributes| attributes[:raw_data]['dt_consulta_optante_simples'] }

      expect(simples.size).to eq(18)
      expect(consulted).not_to be_empty
      expect(consulted).to all(satisfy { |attributes| attributes[:simples_optant_at] == attributes[:raw_data]['dt_consulta_optante_simples'].to_date.in_time_zone })
      expect(not_consulted.pluck(:simples_optant_at)).to all(eq(now))
      expect(customer(1952)[:simples_optant_at]).to be_nil
    end

    it 'splits the e-mails separated by semicolon' do
      expect(customers.map { |attributes| attributes[:emails].size }.max).to be > 1
    end

    context 'when an exporter customer is imported again' do
      let(:exporter_since) { Time.zone.local(2025, 1, 1) }
      let(:previous) { { 294 => { exporter_at: exporter_since } } }

      it 'keeps the stored datetime' do
        expect(customer(294)[:exporter_at]).to eq(exporter_since)
      end
    end

    context 'when a required column is missing' do
      let(:spreadsheet) do
        fixture = read_atua_fixture(:customers)
        atua_spreadsheet(headers: fixture.headers - %w[cd_pessoa], rows: fixture.rows.first(1))
      end

      it 'raises a layout error naming the missing and the received columns' do
        expect { customers }.to raise_error(
          Atua::LayoutError,
          /\AO relatório rel_cliente_detalhado veio sem as colunas obrigatórias cd_pessoa\. Colunas recebidas: nm_pessoa, nm_fantasia/,
        )
      end
    end
  end
end
