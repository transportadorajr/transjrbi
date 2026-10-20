require 'rails_helper'

RSpec.describe Atua::ReadSpreadsheetCommand do
  let(:tenant) { build(:tenant) }

  describe '.call' do
    context 'with the transport documents fixture' do
      it 'reads the header of row 2 and one hash per data row keyed by header' do
        result = described_class.call(tenant, atua_fixture_path(:transport_documents))

        expect(result.headers.size).to eq(199)
        expect(result.headers.first(3)).to eq(%w[cd_ctrc nr_ctrc ds_serie])
        expect(result.rows.size).to eq(420)
        expect(result.rows.first).to include(
          'cd_ctrc' => 80_842.0,
          'id_sintegra' => 'CTRC',
          'dt_emissao' => '01/10/26 16:45',
          'vl_frete_empresa' => 541.25,
          'nr_chave' => '31261091025477000349570010000003971521192668 ',
        )
        expect(result.rows.first['dt_lancamento'].to_date).to eq(Date.new(2026, 10, 1))
      end
    end

    context 'with every fixture' do
      it 'reads all the data rows and matches the totals row' do
        counts = %i[transport_documents manifests expenses customers vehicles].index_with do |name|
          described_class.call(tenant, atua_fixture_path(name)).rows.size
        end

        expect(counts).to eq(transport_documents: 420, manifests: 390, expenses: 1218, customers: 4833, vehicles: 1391)
      end
    end

    context 'with a spreadsheet derived from the fixtures' do
      let(:path) do
        write_atua_spreadsheet(
          totals: totals,
          headers: %w[cd_caixa nm_historico vl_lancamento dt_lancamento_],
          rows: [
            [590_252.0, ' COMBUSTIVEL - DIESEL ', 7815.4, DateTime.new(2026, 10, 1, 10, 30)],
            [nil, '  ', nil, nil],
            [590_253.0, 'CHAPA / CARGA, DESCARGA', 250.35, DateTime.new(2026, 10, 2, 10, 30)],
          ],
        )
      end
      let(:totals) { [nil, nil, 8065.75, nil] }

      after { FileUtils.rm_f(path) }

      it 'skips the empty rows and keeps the raw cell values' do
        result = described_class.call(tenant, path)

        expect(result.rows.size).to eq(2)
        expect(result.rows.first.except('dt_lancamento_')).to eq(
          'cd_caixa' => 590_252.0,
          'nm_historico' => ' COMBUSTIVEL - DIESEL ',
          'vl_lancamento' => 7815.4,
        )
        expect(result.rows.last['dt_lancamento_'].to_date).to eq(Date.new(2026, 10, 2))
      end

      context 'when the sum of the rows does not match the totals row' do
        let(:totals) { [nil, nil, 9000.0, nil] }

        it 'raises a spreadsheet error naming the column, the total and the sum' do
          expect { described_class.call(tenant, path) }.to raise_error(Atua::SpreadsheetError) { |error|
            expect(error.message).to include('não bate com a linha de totais')
            expect(error.message).to include('vl_lancamento (total 9000.0, soma 8065.75)')
          }
        end
      end
    end

    context 'with columns in a different order' do
      let(:path) do
        write_atua_spreadsheet(
          totals: [7815.4, nil],
          headers: %w[vl_lancamento cd_caixa],
          rows: [[7815.4, 590_252.0]],
        )
      end

      after { FileUtils.rm_f(path) }

      it 'maps the cells by the header name' do
        expect(described_class.call(tenant, path).rows).to eq([{ 'cd_caixa' => 590_252.0, 'vl_lancamento' => 7815.4 }])
      end
    end

    context 'with a file that is not an Excel spreadsheet' do
      let(:path) { Rails.root.join('tmp', "atua_not_excel_#{SecureRandom.hex(6)}.xls") }

      before { File.write(path, '<html><body>Sessão expirada</body></html>') }

      after { FileUtils.rm_f(path) }

      it 'raises a spreadsheet error naming the file' do
        expect { described_class.call(tenant, path) }
          .to raise_error(Atua::SpreadsheetError, /Não foi possível abrir a planilha #{path.basename}/)
      end
    end
  end
end
