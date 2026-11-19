module Dashboard
  class RevenueProjectionBreakdown
    DIMENSIONS = %w[vehicle customer_group].freeze
    DEFAULT_DIMENSION = 'vehicle'.freeze

    Row = Data.define(:key, :label, :billed_cents, :projected_cents, :share) do
      def remaining_cents
        projected_cents - billed_cents
      end
    end

    SORT_VALUES = {
      'label' => ->(row) { I18n.transliterate(row.label.to_s).downcase },
      'billed' => ->(row) { row.billed_cents },
      'projected' => ->(row) { row.projected_cents },
    }.freeze

    def initialize(freight, projected_cents: nil)
      @freight = freight
      @projected_cents = projected_cents
    end

    delegate :dimension, to: :freight

    def projected?
      !projected_cents.nil?
    end

    delegate :any?, to: :rows

    def rows
      @rows ||= freight.rows.map { build_row(it) }
    end

    def total
      @total ||= build_row(freight.total)
    end

    def sorted_rows(column, direction)
      return rows unless SORT_VALUES.key?(column.to_s)

      sorted = rows.sort_by { |row| [SORT_VALUES.fetch(column.to_s).call(row), row.key.to_s] }

      direction.to_s == 'desc' ? sorted.reverse : sorted
    end

    private

    attr_reader :freight, :projected_cents

    def build_row(row)
      Row.new(key: row.key, label: row.label, billed_cents: row.gross.cents, projected_cents: project(row.gross.cents), share: row.share)
    end

    def project(cents)
      billed_cents = freight.total.gross.cents
      return cents if !projected? || billed_cents.zero?

      (cents * projected_cents.to_d / billed_cents).round
    end
  end
end
