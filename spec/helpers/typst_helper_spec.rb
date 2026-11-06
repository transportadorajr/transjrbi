require 'rails_helper'

describe TypstHelper do
  describe '#typst_text' do
    it 'escapes quotes and backslashes into a Typst string literal' do
      expect(helper.typst_text('Aço "Inox" \\ Ltda')).to eq('"Aço \"Inox\" \\\\ Ltda"')
    end
  end

  describe '#typst_page_setup' do
    it 'sets a portrait A4 page by default' do
      expect(helper.typst_page_setup).to include('paper: "a4"', 'flipped: false')
    end

    it 'sets a landscape A4 page when the renderer asked for it' do
      expect(helper.typst_page_setup(orientation: :landscape)).to include('paper: "a4"', 'flipped: true')
    end

    it 'rejects an unknown orientation' do
      expect { helper.typst_page_setup(orientation: :sideways) }.to raise_error(ArgumentError)
    end

    it 'uses the given margin' do
      expect(helper.typst_page_setup(margin: '(x: 2cm, y: 1cm)')).to include('margin: (x: 2cm, y: 1cm)')
    end

    it 'numbers the pages in the footer' do
      expect(helper.typst_page_setup).to include('[#"Página" #counter(page).display()]')
    end
  end

  describe '#typst_table_row' do
    it 'turns every value into an escaped Typst string cell' do
      expect(helper.typst_table_row(['74130', 'R$ 555,04', 'A "B"'])).to eq('"74130", "R$ 555,04", "A \"B\"",')
    end
  end

  describe '#typst_table_header' do
    it 'renders the labels as bold white header cells' do
      expect(helper.typst_table_header(%w[Número Placa])).to eq(
        'table.header(text(weight: "bold", fill: white, "Número"), text(weight: "bold", fill: white, "Placa")),',
      )
    end
  end

  describe '#typst_plain' do
    it 'keeps only the text of the markup rendered by the screen helpers' do
      badge = helper.content_tag(:span, 'Ativo', class: 'badge')
      link = helper.link_to('74130 & Cia', '/transport_documents/1')

      expect(helper.typst_plain(helper.safe_join([link, badge], ' '))).to eq('74130 & Cia Ativo')
    end

    it 'turns a blank value into an empty text' do
      expect(helper.typst_plain(nil)).to eq('')
    end
  end

  describe '#typst_table_row with markup' do
    it 'strips the markup before escaping the cell' do
      expect(helper.typst_table_row([helper.content_tag(:strong, 'Aço "Inox"')])).to eq('"Aço \"Inox\"",')
    end
  end

  describe '#typst_table_footer' do
    it 'renders the totals as a bold footer that is not repeated on every page' do
      expect(helper.typst_table_footer(['Total', 'R$ 20,00'])).to eq(
        'table.footer(repeat: false, text(weight: "bold", "Total"), text(weight: "bold", "R$ 20,00")),',
      )
    end

    it 'renders nothing without totals' do
      expect(helper.typst_table_footer(nil)).to be_nil
    end
  end

  describe '#typst_columns and #typst_alignments' do
    it 'lists the width and the alignment of every column' do
      columns = [helper.pdf_column('Nome', '2fr'), helper.pdf_column('Valor', align: :right)]

      expect(helper.typst_columns(columns)).to eq('(2fr, auto)')
      expect(helper.typst_alignments(columns)).to eq('(left, right)')
    end
  end

  describe '#typst_subtitle' do
    it 'renders a centered subtitle' do
      expect(helper.typst_subtitle('Período de outubro')).to include('#align(center', '"Período de outubro"')
    end

    it 'renders nothing without a subtitle' do
      expect(helper.typst_subtitle(nil)).to be_nil
    end
  end

  describe '#typst_highlights' do
    it 'renders every indicator as a labeled box in a grid of four columns' do
      markup = helper.typst_highlights([helper.pdf_highlight('Frete bruto', 'R$ 20.000,00'), helper.pdf_highlight('Viagens', 2)])

      expect(markup).to start_with('#grid(columns: (1fr,) * 4')
      expect(markup).to include('"Frete bruto"', '"R$ 20.000,00"', '"Viagens"', '"2"')
    end

    it 'renders nothing without indicators' do
      expect(helper.typst_highlights([])).to be_nil
    end
  end

  describe '#typst_records_count' do
    it 'counts the listed rows' do
      report = PdfReport.new(title: 'Cidades', columns: [], rows: [%w[Ipatinga], %w[Betim]])

      expect(helper.typst_records_count(report)).to eq('"2 registros listados."')
    end
  end
end
