module TypstHelper
  TYPST_HEADER_FILL = '#1a2a3a'.freeze
  TYPST_BORDER_COLOR = '#cccccc'.freeze
  TYPST_MUTED_COLOR = '#555555'.freeze
  TYPST_HIGHLIGHT_COLUMNS = 4

  def typst_text(value)
    escaped = value.to_s.gsub('\\', '\\\\\\\\').gsub('"', '\"')

    "\"#{escaped}\"".html_safe
  end

  def typst_markup(markup)
    markup.to_s.html_safe
  end

  def typst_plain(value)
    CGI.unescapeHTML(strip_tags(value.to_s)).squish
  end

  def typst_page_setup(orientation: :portrait, margin: '(x: 1.5cm, y: 1.5cm)')
    typst_markup(<<~TYPST)
      #set page(
        paper: "a4",
        flipped: #{TypstPdfGenerator.orientation(orientation) == :landscape},
        margin: #{margin},
        footer: context align(center, text(8pt)[##{typst_text(t('typst.page.label'))} #counter(page).display()]),
      )
    TYPST
  end

  def typst_columns(columns)
    typst_markup("(#{columns.map(&:width).join(', ')})")
  end

  def typst_alignments(columns)
    typst_markup("(#{columns.map(&:align).join(', ')})")
  end

  def typst_table_header(labels)
    cells = labels.map { |label| "text(weight: \"bold\", fill: white, #{typst_text(typst_plain(label))})" }

    typst_markup("table.header(#{cells.join(', ')}),")
  end

  def typst_table_row(values)
    typst_markup("#{values.map { |value| typst_text(typst_plain(value)) }.join(', ')},")
  end

  def typst_table_footer(values)
    return if values.blank?

    cells = values.map { |value| "text(weight: \"bold\", #{typst_text(typst_plain(value))})" }

    typst_markup("table.footer(repeat: false, #{cells.join(', ')}),")
  end

  def typst_subtitle(subtitle)
    return if subtitle.blank?

    typst_markup("#align(center, text(10pt, fill: rgb(\"#{TYPST_MUTED_COLOR}\"), #{typst_text(typst_plain(subtitle))}))")
  end

  def typst_highlights(highlights)
    return if highlights.blank?

    cells = highlights.map do |highlight|
      "block(width: 100%, inset: 6pt, stroke: 0.4pt + rgb(\"#{TYPST_BORDER_COLOR}\"), " \
        "[#text(8pt, fill: rgb(\"#{TYPST_MUTED_COLOR}\"), #{typst_text(typst_plain(highlight.label))}) #linebreak() " \
        "#text(11pt, weight: \"bold\", #{typst_text(typst_plain(highlight.value))})])"
    end

    typst_markup("#grid(columns: (1fr,) * #{TYPST_HIGHLIGHT_COLUMNS}, gutter: 6pt, #{cells.join(', ')})\n\n#v(0.6em)")
  end

  def typst_listing_body(report)
    return typst_markup("#align(center, text(10pt, #{typst_text(t('shared.no_content.title'))}))") if report.empty?

    render 'shared/pdf_table', report:
  end

  def typst_records_count(report)
    typst_text(t('typst.records_count', count: report.rows.size))
  end

  def typst_generated_at
    typst_text(t('typst.generated_at', time: l(Time.current, format: :date_time)))
  end

  def typst_section_title(title)
    typst_markup('#block(width: 100%, inset: (x: 4pt, top: 4pt, bottom: 2pt), ' \
                 "text(9pt, weight: \"bold\", fill: rgb(\"#{TYPST_HEADER_FILL}\"), #{typst_text(typst_plain(title).upcase)}))")
  end

  def typst_field_grid(fields, columns: 2)
    cells = fields.map do |label, value|
      "block(width: 100%, inset: (x: 4pt, y: 3pt), [#text(7pt, weight: \"bold\", fill: rgb(\"#{TYPST_MUTED_COLOR}\"), " \
        "#{typst_text(typst_plain(label).upcase)}) #linebreak() #text(9pt, #{typst_text(typst_plain(value))})])"
    end

    typst_markup("#grid(columns: (1fr,) * #{columns}, row-gutter: 2pt, #{cells.join(', ')})")
  end

  def typst_paragraph(value)
    typst_markup("#block(width: 100%, inset: (x: 4pt, y: 2pt), text(9pt, #{typst_text(value.to_s.strip)}))")
  end

  def typst_signatures(labels, columns: 2, width: '100%')
    cells = labels.map do |label|
      'block(width: 100%, inset: (top: 18pt, x: 8pt), [#line(length: 100%, stroke: 0.5pt) ' \
        "#align(center, text(8pt, fill: rgb(\"#{TYPST_MUTED_COLOR}\"), #{typst_text(typst_plain(label))}))])"
    end

    typst_markup("#align(center, block(breakable: false, width: #{width}, grid(columns: (1fr,) * #{columns}, gutter: 6pt, #{cells.join(', ')})))")
  end

  def pdf_column(label, width = 'auto', align: :left)
    PdfReport::Column.new(label:, width:, align:)
  end

  def pdf_highlight(label, value)
    PdfReport::Highlight.new(label:, value:)
  end
end
