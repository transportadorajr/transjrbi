module XlsxFiles
  PARTS = {
    '[Content_Types].xml' => <<~XML,
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
      </Types>
    XML
    '_rels/.rels' => <<~XML,
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
      </Relationships>
    XML
    'xl/workbook.xml' => <<~XML,
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets><sheet name="KM" sheetId="1" r:id="rId1"/></sheets>
      </workbook>
    XML
    'xl/_rels/workbook.xml.rels' => <<~XML,
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
      </Relationships>
    XML
    'xl/styles.xml' => <<~XML,
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
      </styleSheet>
    XML
  }.freeze

  def xlsx_file(rows)
    file = Tempfile.new(%w[distance_adjustments .xlsx])
    file.close

    Zip::File.open(file.path, create: true) do |zip|
      PARTS.each { |name, content| zip.get_output_stream(name) { |stream| stream.write(content) } }
      zip.get_output_stream('xl/worksheets/sheet1.xml') { |stream| stream.write(xlsx_sheet(rows)) }
    end

    file.path
  end

  private

  def xlsx_sheet(rows)
    lines = rows.each_with_index.map do |values, index|
      cells = values.each_with_index.map { |value, column| xlsx_cell(value, "#{('A'.ord + column).chr}#{index + 1}") }
      "<row r=\"#{index + 1}\">#{cells.join}</row>"
    end

    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
      "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData>#{lines.join}</sheetData></worksheet>"
  end

  def xlsx_cell(value, reference)
    return "<c r=\"#{reference}\"><v>#{value}</v></c>" if value.is_a?(Numeric)

    "<c r=\"#{reference}\" t=\"inlineStr\"><is><t>#{ERB::Util.html_escape(value)}</t></is></c>"
  end
end

RSpec.configure do |config|
  config.include XlsxFiles
end
