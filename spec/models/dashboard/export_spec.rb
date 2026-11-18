require 'rails_helper'

RSpec.describe Dashboard::Export do
  subject(:dashboard) do
    described_class.new(documents: tenant.atua_transport_documents, manifests: tenant.atua_manifests, customers: tenant.atua_customers,
                        plants: tenant.export_plants.activated, period: october, filters:, today: Date.new(2026, 10, 21))
  end

  let!(:tenant) { create(:tenant) }
  let(:october) { Date.new(2026, 10, 1)..Date.new(2026, 10, 31) }
  let(:filters) { {} }
  let!(:arcelor) { create(:customer_group, tenant:, name: 'ARCELORMITTAL') }
  let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
  let!(:sul_fluminense) { create(:export_plant, tenant:, customer_group: arcelor, name: 'Sul Fluminense', cities: ['RESENDE', 'Barra Mansa']) }

  before do
    create(:atua_customer, tenant:, code: 100, name: 'ARCELORMITTAL BRASIL S.A.', customer_group: arcelor)
    create(:atua_customer, tenant:, code: 200, name: 'USINAS SIDERURGICAS DE MINAS GERAIS', customer_group: usiminas)
    create(:atua_customer, tenant:, code: 300, name: 'ACEROS ASUNCION SA', city: 'ASUNCION', state: 'EX', country_type: 'paraguay')
    create(:atua_customer, tenant:, code: 301, name: 'ACINDAR', city: 'BUENOS AIRES', state: 'EX', country_type: 'argentina')
    create(:atua_customer, tenant:, code: 302, name: 'FERROSIDER S/A', city: 'EXTERIOR', state: 'EX')
  end

  def create_loading(code:, on:, documents:, status: 'Encerrado', target: tenant)
    create(:atua_manifest, tenant: target, code:, number: code.to_s, status:, trip_started_at: on.in_time_zone.change(hour: 8))
    documents.each do |number, attributes|
      unless Atua::TransportDocument.exists?(tenant: target, number:)
        create(:atua_transport_document, tenant: target, number:, cargo_destination_type: 'export', taker_code: 100, recipient_code: 300,
                                         origin_city: 'JUIZ DE FORA', origin_state: 'MG', **attributes)
      end
      create(:atua_manifest_document, tenant: target, manifest_code: code, transport_document_number: number)
    end
  end

  def row_values(rows)
    rows.map { |row| [row.customer_group, row.plant, row.country, row.tons, row.loadings_count, row.documents_count, row.share] }
  end

  context 'with loadings of several plants and countries' do
    before do
      create_loading(code: 1, on: Date.new(2026, 10, 2), documents: [
                       ['74001', { weight_tons: BigDecimal('30') }],
                       ['74002', { weight_tons: nil, weight_kg: BigDecimal('27500') }],
                       ['74003', { document_kind: 'ce', weight_tons: BigDecimal('57.5') }],
                       ['74004', { weight_tons: BigDecimal('30'), canceled_at: Time.zone.local(2026, 10, 2, 9) }],
                       ['74005', { weight_tons: BigDecimal('30'), issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT }],
                       ['74006', { weight_tons: BigDecimal('30'), cargo_destination_type: 'national' }],
                     ])
      create_loading(code: 2, on: Date.new(2026, 10, 5), documents: [['74007', { weight_tons: 32, recipient_code: 301, origin_city: 'RESENDE', origin_state: 'RJ' }]])
      create_loading(code: 3, on: Date.new(2026, 10, 6), documents: [['74008', { weight_tons: 30, recipient_code: 301, origin_city: 'BARRA MANSA', origin_state: 'RJ' }]])
      create_loading(code: 4, on: Date.new(2026, 10, 8), documents: [['74009', { weight_tons: 25, taker_code: 200, recipient_code: 302, origin_city: 'IPATINGA' }]])
      create_loading(code: 5, on: Date.new(2026, 10, 15), documents: [['74001', {}]])
      create_loading(code: 6, on: Date.new(2026, 10, 16), status: 'Cancelado', documents: [['74010', { weight_tons: 40 }]])
      create_loading(code: 7, on: Date.new(2026, 11, 2), documents: [['74011', { weight_tons: 40 }]])
      create(:atua_transport_document, tenant:, number: '74012', cargo_destination_type: 'export', taker_code: 100, weight_tons: 40)
      create_loading(code: 8, on: Date.new(2026, 10, 2), target: create(:tenant), documents: [['74013', { weight_tons: 40 }]])
    end

    it 'adds up the tons of each customer group, plant and country of destination' do
      expect(row_values(dashboard.rows)).to eq(
        [
          ['ARCELORMITTAL', 'Sul Fluminense', 'Argentina', BigDecimal('62'), 2, 2, BigDecimal('42.9')],
          ['ARCELORMITTAL', 'JUIZ DE FORA/MG', 'Paraguai', BigDecimal('57.5'), 1, 2, BigDecimal('39.8')],
          ['USIMINAS', 'IPATINGA/MG', 'País não identificado', BigDecimal('25'), 1, 1, BigDecimal('17.3')],
        ],
      )
      expect(row_values([dashboard.total])).to eq([['Total', 'Total', 'Total', BigDecimal('144.5'), 4, 5, BigDecimal('100')]])
    end

    it 'counts the cargo of a document once, on its first manifest, leaving CEs, cancellations and complements out' do
      expect(dashboard.documents_for('total').map(&:number)).to eq(%w[74001 74002 74007 74008 74009])
      expect(dashboard.documents_for('total').first).to have_attributes(manifest_code: 1, trip_on: Date.new(2026, 10, 2), tons: BigDecimal('30'))
    end

    it 'lists the documents of a row and nothing for an unknown key' do
      row = dashboard.rows.first

      expect(dashboard.find_row(row.key)).to eq(row)
      expect(dashboard.documents_for(row.key).map(&:number)).to eq(%w[74007 74008])
      expect(dashboard.find_row('unknown')).to be_nil
      expect(dashboard.documents_for('unknown')).to be_nil
    end

    context 'when filtered by plant' do
      let(:filters) { { plant: "plant-#{sul_fluminense.id}" } }

      it 'keeps only the loadings of the plant' do
        expect(dashboard.rows.map(&:plant)).to eq(['Sul Fluminense'])
        expect(dashboard.total.tons).to eq(BigDecimal('62'))
      end
    end

    context 'when filtered by customer group and an unknown country' do
      let(:filters) { { customer_group_id: usiminas.id.to_s, country: 'unknown', plant: '' } }

      it 'keeps only the matching loadings' do
        expect(dashboard.rows.map(&:plant)).to eq(['IPATINGA/MG'])
      end
    end

    it 'offers the registered plants and the cities without a plant as options' do
      expect(dashboard.plant_options).to eq([['IPATINGA/MG', 'city-IPATINGA-MG'], ['JUIZ DE FORA/MG', 'city-JUIZDEFORA-MG'],
                                             ['Sul Fluminense', "plant-#{sul_fluminense.id}"]])
      expect(dashboard.customer_group_options).to eq([['ARCELORMITTAL', arcelor.id], ['USIMINAS', usiminas.id]])
      expect(dashboard.country_options.last).to eq(['País não identificado', 'unknown'])
    end
  end

  context 'with loadings of the current and the previous weeks and months' do
    before do
      create_loading(code: 1, on: Date.new(2026, 10, 19), documents: [['74001', { weight_tons: 20 }]])
      create_loading(code: 2, on: Date.new(2026, 10, 12), documents: [['74002', { weight_tons: 10 }]])
      create_loading(code: 3, on: Date.new(2026, 9, 10), documents: [['74003', { weight_tons: 40 }]])
      create_loading(code: 4, on: Date.new(2026, 9, 25), documents: [['74004', { weight_tons: 99, recipient_code: 301 }]])
    end

    it 'compares the week to date with the same days of the previous week' do
      expect(dashboard.week_comparison).to have_attributes(
        current_period: Date.new(2026, 10, 18)..Date.new(2026, 10, 21), previous_period: Date.new(2026, 10, 11)..Date.new(2026, 10, 14),
        current_tons: BigDecimal('20'), previous_tons: BigDecimal('10'), current_loadings: 1, previous_loadings: 1, variation: BigDecimal('100')
      )
    end

    it 'compares the month to date with the same days of the previous month' do
      expect(dashboard.month_comparison).to have_attributes(
        current_period: Date.new(2026, 10, 1)..Date.new(2026, 10, 21), previous_period: Date.new(2026, 9, 1)..Date.new(2026, 9, 21),
        current_tons: BigDecimal('30'), previous_tons: BigDecimal('40'), current_loadings: 2, previous_loadings: 1, variation: BigDecimal('-25')
      )
    end

    it 'builds the monthly evolution by country of destination' do
      expect(dashboard.monthly_data).to eq(
        [
          { name: 'Argentina', data: { 'Mai/2026' => 0.0, 'Jun/2026' => 0.0, 'Jul/2026' => 0.0, 'Ago/2026' => 0.0, 'Set/2026' => 99.0, 'Out/2026' => 0.0 } },
          { name: 'Paraguai', data: { 'Mai/2026' => 0.0, 'Jun/2026' => 0.0, 'Jul/2026' => 0.0, 'Ago/2026' => 0.0, 'Set/2026' => 40.0, 'Out/2026' => 30.0 } },
        ],
      )
    end

    it 'builds the weekly evolution of the last weeks' do
      expect(dashboard.weekly_data.map { |series| [series[:name], series[:data].keys] }).to eq(
        [['Paraguai', %w[27/09 04/10 11/10 18/10 25/10]]],
      )
      expect(dashboard.weekly_data.first[:data].values).to eq([0.0, 0.0, 10.0, 20.0, 0.0])
    end
  end

  context 'without loadings' do
    it 'is empty with a zeroed total and comparisons without variation' do
      expect(dashboard).to be_empty
      expect(row_values([dashboard.total])).to eq([['Total', 'Total', 'Total', BigDecimal('0'), 0, 0, BigDecimal('0')]])
      expect(dashboard.week_comparison.variation).to be_nil
      expect(dashboard.monthly_data).to eq([])
    end
  end
end
