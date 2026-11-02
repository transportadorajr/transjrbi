require 'rails_helper'

RSpec.describe Atua::MapTransportDocumentsCommand do
  let(:tenant) { build(:tenant) }
  let(:spreadsheet) { read_atua_fixture(:transport_documents) }
  let(:now) { Time.zone.local(2026, 10, 13, 10, 0) }
  let(:previous) { {} }
  let(:documents) { travel_to(now) { described_class.call(tenant, spreadsheet, previous:) } }

  def document(code)
    documents.find { |attributes| attributes[:code] == code }
  end

  describe '.call' do
    it 'maps one record per row' do
      expect(documents.size).to eq(420)
      expect(documents.pluck(:code).uniq.size).to eq(420)
    end

    it 'maps every attribute of a CT-e' do
      expect(document(80_842).except(:raw_data)).to eq(
        code: 80_842, number: 397, series: 1, issue_kind: 'Normal', service_kind: 'Normal', cfop: 6352, cte_status: 'Autorizado',
        access_key: '31261091025477000349570010000003971521192668',
        issued_at: Time.zone.local(2026, 10, 1, 16, 45), posted_on: Date.new(2026, 10, 1), arrival_on: Date.new(2026, 10, 3),
        due_dates: [Date.new(2026, 10, 29)], canceled_at: nil, cancellation_reason: nil,
        branch_code: 8042, branch_name: 'EMPRESA 01', headquarters_code: 2, headquarters_name: 'EMPRESA 02',
        agency_code: 2, agency_name: 'EMPRESA 02', issuer_code: 6001, issuer_name: 'PESSOA 05080',
        origin_city: 'JOAO MONLEVADE', origin_state: 'MG', origin_city_code: 2017,
        destination_city: 'TRES LAGOAS', destination_state: 'MS', destination_city_code: 1605,
        sender_code: 7752, sender_name: 'PESSOA 00428', sender_document: '12.261.462/0066-97', sender_document_digits: '12261462006697',
        recipient_code: 7761, recipient_name: 'PESSOA 02842', recipient_document: '72.177.813/0001-62', recipient_document_digits: '72177813000162',
        payer_code: 7752, payer_name: 'PESSOA 00428', payer_document: '12.261.462/0066-97', payer_document_digits: '12261462006697',
        taker_code: 7752, taker_name: 'PESSOA 00428',
        consignee_code: nil, consignee_name: nil, consignee_document: nil, consignee_document_digits: nil,
        driver_code: 9267, driver_name: 'PESSOA 04610', driver_document: '538.606.100/31', driver_document_digits: '53860610031',
        vehicle_code: 812, plate: 'ZIZ7D35', trailer_plate: 'FUY7V04', axles: 6, vehicle_ownership: 'Próprio',
        weight_tons: BigDecimal('1.917'), weight_kg: BigDecimal('1917'), product_quantity: BigDecimal('70'),
        product_name: 'FERRO (FIO MAQUINA/ VERGALHAO ROLO)', ncm: '7213', goods_value_cents: 818_150,
        goods_invoice_numbers: %w[2082496], goods_invoice_keys: %w[31260812261462006697550000020824961065968228],
        complemented_number: nil, manifest_numbers: [183], ciot: nil, operational_unit: 'FROTA PROPRIA',
        cargo_destination: 'Nacional', route: 'MG / JOAO MONLEVADE X MS / TRES LAGOAS', shipment_number: 'EMBARQUE 692',
        freight_cents: 54_125, weight_freight_cents: 50_336, value_freight_cents: 45_330, ad_valorem_cents: 0,
        other_charges_cents: 0, toll_cents: 0, icms_base_cents: 54_125, icms_cents: 3788, icms_st_cents: 0,
        federal_tax_cents: 5006, ibs_cents: 45, cbs_cents: 408, result_cents: 0, driver_freight_cents: 0,
        advance_cents: nil, commission_cents: 0, insurance_cents: 0, cost_cents: 0,
        result_margin_percentage: BigDecimal('83.75'), distance_km: BigDecimal('1055'),
        document_kind: 'cte', billing_number: 131_391, charged_at: now, nfse_pending_at: nil, vehicle_sale: false
      )
    end

    it 'keeps the whole row in raw_data' do
      expect(document(80_842)[:raw_data]).to eq(spreadsheet.rows.first)
      expect(document(80_842)[:raw_data].size).to eq(199)
    end

    it 'maps a CE without MDF-e, access key or status' do
      expect(document(81_002)).to include(document_kind: 'ce', series: 0, manifest_numbers: [], access_key: nil, cte_status: nil)
    end

    it 'maps a CT-e with two MDF-e into a list of manifest numbers' do
      expect(document(80_909)[:manifest_numbers]).to eq([40_798, 40_834])
    end

    it 'maps a CT-e with several invoices into lists of numbers and keys' do
      expect(document(80_824)).to include(
        goods_invoice_numbers: %w[4199237 4197775 4199241],
        goods_invoice_keys: %w[
          81063508489706496290733894964404088691645989 48813278481581821361559359836338941951406587
          28686549022740993852105376056658325708222809
        ],
      )
    end

    it 'strips the trailing spaces of the access keys and the CIOT' do
      expect(documents.filter_map { |attributes| attributes[:access_key] }).to all(match(/\A\d{44}\z/))
      expect(documents.filter_map { |attributes| attributes[:ciot] }).to all(match(/\A\S+\z/))
    end

    it 'splits id_cobrado into the invoice number and charged_at' do
      expect(document(80_848)).to include(billing_number: nil, charged_at: nil)
      expect(documents.count { |attributes| attributes[:charged_at].nil? }).to eq(65)
    end

    context 'when a charged document is imported again' do
      let(:charged_on) { Time.zone.local(2026, 10, 2, 9, 0) }
      let(:previous) { { 80_842 => { charged_at: charged_on }, 80_848 => { charged_at: charged_on } } }

      it 'keeps the stored charged_at while it is still charged and clears it when it is not' do
        expect(document(80_842)[:charged_at]).to eq(charged_on)
        expect(document(80_848)[:charged_at]).to be_nil
      end
    end

    context 'with documents billed to Foz do Iguacu' do
      let(:spreadsheet) do
        fixture = read_atua_fixture(:transport_documents)
        juiz_de_fora = { 'nm_cidade_origem' => 'JUIZ DE FORA', 'ds_uf_origem' => 'MG', 'cd_cidade_origem' => 1234, 'nm_cidade_destino' => 'FOZ DO IGUACU', 'ds_uf_destino' => 'PR' }
        truck = { 'ds_placa' => 'BDZ8J90', 'ds_placa_carreta' => 'AQZ1D12', 'cd_veiculo' => 585 }
        rows = [
          [80_842, 'CE', 'ARCELORMITTAL BRASIL S.A.'],
          [80_848, 'CTRC', 'ARCELORMITTAL BRASIL S.A.'],
          [80_909, 'CE', 'USIMINAS'],
          [80_824, 'CE', 'USIMINAS', { 'ds_placa' => 'INT6R00' }],
          [81_002, 'CE', 'ARCELORMITTAL BRASIL S.A.', { 'nm_cidade_destino' => 'TRES LAGOAS', 'ds_uf_destino' => 'MS' }],
        ].map do |code, kind, taker, overrides|
          fixture.rows.find { |row| row['cd_ctrc'].to_i == code }.merge(juiz_de_fora, truck, 'id_sintegra' => kind, 'nm_pessoa_tomador' => taker, **overrides.to_h)
        end
        atua_spreadsheet(headers: fixture.headers, rows:)
      end
      let(:truck_vehicle) { { plate: 'BDZ8J90', trailer_plate: 'AQZ1D12', vehicle_code: 585 } }

      it 'moves the origin of an Arcelor CE to Foz do Iguacu and keeps the issued one in raw_data' do
        expect(document(80_842)).to include(origin_city: 'FOZ DO IGUACU', origin_state: 'PR', origin_city_code: 2946)
        expect(document(80_842)[:raw_data]).to include('nm_cidade_origem' => 'JUIZ DE FORA')
      end

      it 'moves an Arcelor CE to the international plate without a trailer and keeps the issued plate in raw_data' do
        expect(document(80_842)).to include(plate: 'INT6R00', trailer_plate: nil, vehicle_code: 585)
        expect(document(80_842)[:raw_data]).to include('ds_placa' => 'BDZ8J90', 'ds_placa_carreta' => 'AQZ1D12')
      end

      it 'moves the origin of a CE of the international plate to Foz do Iguacu' do
        expect(document(80_824)).to include(origin_city: 'FOZ DO IGUACU', origin_state: 'PR', origin_city_code: 2946)
      end

      it 'keeps the origin and the vehicle of an Arcelor CE bound for another city' do
        expect(document(81_002)).to include(origin_city: 'JUIZ DE FORA', origin_state: 'MG', origin_city_code: 1234, **truck_vehicle)
      end

      it 'keeps the origin and the vehicle of an Arcelor CT-e' do
        expect(document(80_848)).to include(origin_city: 'JUIZ DE FORA', origin_state: 'MG', origin_city_code: 1234, **truck_vehicle)
      end

      it 'keeps the origin and the vehicle of a CE from another customer' do
        expect(document(80_909)).to include(origin_city: 'JUIZ DE FORA', origin_state: 'MG', origin_city_code: 1234, **truck_vehicle)
      end

      context 'when the international vehicle is registered' do
        let(:tenant) { create(:tenant) }
        let!(:international_vehicle) { create(:atua_vehicle, tenant:, plate: 'INT6R00', code: 824) }

        it 'moves an Arcelor CE to the international vehicle' do
          expect(document(80_842)).to include(plate: 'INT6R00', trailer_plate: nil, vehicle_code: international_vehicle.code)
        end

        it 'keeps the vehicle of an Arcelor CT-e' do
          expect(document(80_848)).to include(truck_vehicle)
        end
      end
    end

    context 'with documents sent by the company itself' do
      let(:spreadsheet) do
        fixture = read_atua_fixture(:transport_documents)
        own_sender = { 'nr_cnpj_cpf_remetente' => '10.212.838/0001-00', 'nm_pessoa_remetente' => 'TRANSJR TRANSPORTADORA LTDA' }
        rows = [
          [80_842, 'CE', own_sender.merge('vl_frete_empresa' => 718_185, 'vl_nota_fiscal' => 718_185)],
          [80_848, 'CE', own_sender.merge('vl_frete_empresa' => 9000, 'vl_nota_fiscal' => 1000)],
          [80_909, 'CTRC', own_sender.merge('vl_frete_empresa' => 1, 'vl_nota_fiscal' => 1)],
          [80_824, 'CE', { 'vl_frete_empresa' => 450_000, 'vl_nota_fiscal' => 450_000 }],
          [81_002, 'CE', own_sender.merge('vl_frete_empresa' => 0, 'vl_nota_fiscal' => 0)],
        ].map do |code, kind, overrides|
          fixture.rows.find { |row| row['cd_ctrc'].to_i == code }.merge('id_sintegra' => kind, **overrides)
        end
        atua_spreadsheet(headers: fixture.headers, rows:)
      end

      it 'marks a CE of the company itself whose freight equals the goods value as a vehicle sale' do
        expect(document(80_842)).to include(document_kind: 'ce', freight_cents: 71_818_500, goods_value_cents: 71_818_500, vehicle_sale: true)
      end

      it 'keeps an internal shipment CE whose freight differs from the goods value as a freight' do
        expect(document(80_848)).to include(vehicle_sale: false)
      end

      it 'keeps a CT-e whose freight equals the goods value as a freight' do
        expect(document(80_909)).to include(document_kind: 'cte', vehicle_sale: false)
      end

      it 'keeps a CE sent by another company whose freight equals the goods value as a freight' do
        expect(document(80_824)).to include(document_kind: 'ce', vehicle_sale: false)
      end

      it 'keeps a CE of the company itself without freight as a freight' do
        expect(document(81_002)).to include(vehicle_sale: false)
      end
    end

    context 'when a required column is missing' do
      let(:spreadsheet) do
        fixture = read_atua_fixture(:transport_documents)
        atua_spreadsheet(headers: fixture.headers - %w[cd_ctrc nr_mdfe], rows: fixture.rows.first(1))
      end

      it 'raises a layout error naming the missing and the received columns' do
        expect { documents }.to raise_error(Atua::LayoutError) { |error|
          expect(error.message).to start_with('O relatório rel_ctrc_detalhado veio sem as colunas obrigatórias cd_ctrc, nr_mdfe.')
          expect(error.message).to include('Colunas recebidas: nr_ctrc, ds_serie')
        }
      end
    end

    context 'when the report brings a new column' do
      let(:spreadsheet) do
        fixture = read_atua_fixture(:transport_documents)
        rows = fixture.rows.first(1).map { |row| row.merge('vl_frete_novo' => 10.0) }
        atua_spreadsheet(headers: fixture.headers + %w[vl_frete_novo], rows:)
      end

      it 'accepts it, keeps it in raw_data and logs it' do
        allow(Rails.logger).to receive(:info)

        expect(documents.first[:raw_data]['vl_frete_novo']).to eq(10.0)
        expect(Rails.logger).to have_received(:info).with(
          'O relatório rel_ctrc_detalhado trouxe colunas novas, guardadas só em raw_data: vl_frete_novo.',
        )
      end
    end

    context 'when the freight is charged in several installments' do
      let(:spreadsheet) do
        fixture = read_atua_fixture(:transport_documents)
        rows = fixture.rows.first(1).map { |row| row.merge('dt_vencimento_titulo' => '31/01/2025, 02/09/2025, 27/03/2026') }
        atua_spreadsheet(headers: fixture.headers, rows:)
      end

      it 'maps every installment due date into a list' do
        expect(documents.sole[:due_dates]).to eq([Date.new(2025, 1, 31), Date.new(2025, 9, 2), Date.new(2026, 3, 27)])
      end
    end

    context 'with an unknown document kind' do
      let(:spreadsheet) do
        fixture = read_atua_fixture(:transport_documents)
        atua_spreadsheet(headers: fixture.headers, rows: fixture.rows.first(1).map { |row| row.merge('id_sintegra' => 'NFSE') })
      end

      it 'raises a conversion error naming the column' do
        expect { documents }.to raise_error(Atua::ConversionError, 'Coluna id_sintegra do relatório rel_ctrc_detalhado: tipo de documento "NFSE" desconhecido.')
      end
    end
  end
end
