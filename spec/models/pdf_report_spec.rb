require 'rails_helper'

describe PdfReport do
  describe '.new' do
    it 'has no subtitle, totals or indicators by default' do
      report = described_class.new(title: 'Relatório de Cidades', columns: [], rows: [])

      expect(report.subtitle).to be_nil
      expect(report.totals).to be_nil
      expect(report.highlights).to eq([])
    end
  end

  describe '#empty?' do
    it 'is empty without rows' do
      expect(described_class.new(title: 'Relatório', columns: [], rows: [])).to be_empty
    end

    it 'is not empty with rows' do
      expect(described_class.new(title: 'Relatório', columns: [], rows: [%w[Ipatinga]])).not_to be_empty
    end
  end

  describe PdfReport::Column do
    it 'is left aligned with an automatic width by default' do
      column = described_class.new(label: 'Nome')

      expect(column.width).to eq('auto')
      expect(column.align).to eq(:left)
    end
  end
end
