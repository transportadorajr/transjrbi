require 'rails_helper'

RSpec.describe Atua::MapManifestsCommand do
  let(:tenant) { build(:tenant) }
  let(:spreadsheet) { read_atua_fixture(:manifests) }
  let(:manifests) { described_class.call(tenant, spreadsheet) }

  def manifest(code)
    manifests.find { |attributes| attributes[:code] == code }
  end

  describe '.call' do
    it 'groups the document rows by cd_manifesto' do
      expect(manifests.size).to eq(217)
      expect(manifests.sum { |attributes| attributes[:documents].size }).to eq(390)
    end

    it 'maps every attribute of the manifest header' do
      expect(manifest(41_236).except(:raw_data, :documents)).to eq(
        code: 41_236, model: 58, number: 40_772, series: 1, branch_name: 'EMPRESA 02',
        company_state: 'PR', company_city: 'CASCAVEL',
        issued_on: Date.new(2026, 10, 1), departure_on: Date.new(2026, 10, 1),
        notes: "Início da viagem: 01/10/2026 10:14\nInformações dos Documentos Fiscais vinculados ao Manifesto: \n" \
               "CT-e 41261091025477000187570010000741291693437539\nCT-e 41261091025477000187570010000741301318702362\n" \
               'Percurso: SP / SAO PAULO',
        plate: 'BND3D89', access_key: '41261091025477000187580010000407721527869440',
        goods_value_cents: 11_345_230, status: 'Encerrado',
        trip_started_at: Time.zone.local(2026, 10, 1, 10, 14),
        closed_at: Time.zone.local(2026, 10, 3, 8, 31)
      )
      expect(manifest(41_236)[:raw_data]).to eq(spreadsheet.rows.first)
    end

    it 'maps every attribute of a document of the manifest' do
      expect(manifest(41_236)[:documents].first.except(:raw_data)).to eq(
        manifest_code: 41_236, branch_name: 'EMPRESA 02',
        transport_document_number: 74_130, transport_document_series: 1,
        goods_invoice_numbers: %w[1679763], goods_value_cents: 3_232_595,
        weight_kg: BigDecimal('8043'), weight_tons: BigDecimal('8.043'),
        freight_cents: 324_165, freight_payment: 'CIF',
        sender_name: 'PESSOA 05086', recipient_name: 'PESSOA 00196', origin_agency_name: 'EMPRESA 02',
        origin_state: 'MG', origin_city: 'JUIZ DE FORA', destination_state: 'PR', destination_city: 'FOZ DO IGUACU',
        calculated_distance_km: BigDecimal('1705.5882704081196'), document_distance_km: BigDecimal('1537')
      )
      expect(manifest(41_236)[:documents].first[:raw_data]).to eq(spreadsheet.rows.first)
    end

    it 'keeps every document of a manifest with several documents' do
      expect(manifest(41_239)[:documents].pluck(:transport_document_number)).to eq([74_136, 74_134, 74_135, 74_137, 74_133])
    end

    it 'extracts the start of the trip from the notes of every manifest' do
      expect(manifests.pluck(:trip_started_at)).to all(be_a(ActiveSupport::TimeWithZone))
    end

    it 'leaves closed_at empty for a manifest that was not closed' do
      open_manifests = manifests.select { |attributes| attributes[:raw_data]['dt_encerramento'].nil? }

      expect(open_manifests).not_to be_empty
      expect(open_manifests.pluck(:closed_at)).to all(be_nil)
    end

    context 'when a required column is missing' do
      let(:spreadsheet) do
        fixture = read_atua_fixture(:manifests)
        atua_spreadsheet(headers: fixture.headers - %w[cd_manifesto], rows: fixture.rows.first(1))
      end

      it 'raises a layout error naming the missing and the received columns' do
        expect { manifests }.to raise_error(
          Atua::LayoutError,
          /\AO relatório rel_manifesto_detalhado veio sem as colunas obrigatórias cd_manifesto\. Colunas recebidas: id_modelo, nr_manifesto/,
        )
      end
    end
  end
end
