class PdfReport < Data.define(:title, :subtitle, :columns, :rows, :totals, :highlights)
  Column = Data.define(:label, :width, :align) do
    def initialize(label:, width: 'auto', align: :left)
      super
    end
  end

  Highlight = Data.define(:label, :value)

  def initialize(title:, columns:, rows:, subtitle: nil, totals: nil, highlights: [])
    super
  end

  delegate :empty?, to: :rows
end
