require 'rails_helper'
require 'typst_pdf_generator'

describe TypstPdfGenerator do
  describe '.generate' do
    it 'compiles the Typst markup into a PDF' do
      pdf = described_class.generate("#set page(paper: \"a4\", flipped: true)\nRelatório de teste")

      expect(pdf).to start_with('%PDF')
      expect(PDF::Inspector::Text.analyze(pdf).strings.join).to include('Relatório de teste')

      width, height = PDF::Inspector::Page.analyze(pdf).pages.first[:size]
      expect(width).to be > height
    end

    it 'raises the compiler diagnostics when the markup is broken' do
      expect { described_class.generate('#table(') }.to raise_error(RuntimeError, /\AErro de compilação no Typst-Rust: line 1/)
    end

    it 'refuses to load files from the disk' do
      expect { described_class.generate('#image("/etc/hosts")') }.to raise_error(RuntimeError, /external files and packages cannot be loaded/)
    end

    it 'raises a setup hint when the engine binary is missing' do
      stub_const('ENV', ENV.to_h.merge('TYPST_PDF_BINARY' => '/nonexistent/rust_typst_pdf'))

      expect { described_class.generate('texto') }.to raise_error(
        RuntimeError, 'Motor de PDF não encontrado em /nonexistent/rust_typst_pdf. Execute bin/setup --skip-server para compilá-lo.'
      )
    end
  end

  describe '.orientation' do
    it 'defaults to portrait' do
      expect(described_class.orientation(nil)).to eq(:portrait)
    end

    it 'accepts landscape given as a string or a symbol' do
      expect(described_class.orientation('landscape')).to eq(:landscape)
      expect(described_class.orientation(:landscape)).to eq(:landscape)
    end

    it 'rejects an unknown orientation' do
      expect { described_class.orientation(:sideways) }.to raise_error(
        ArgumentError, 'Orientação de página inválida: sideways. Use uma destas: portrait, landscape.'
      )
    end
  end
end
