module Dashboard
  class Trip
    DIMENSIONS = %w[driver vehicle].freeze
    DEFAULT_DIMENSION = 'driver'.freeze
    HISTORY_MONTHS = 6
    HISTORY_WEEKS = 12
    WEEK_START = :sunday
    RANKING_LIMIT = 15
    TOTAL_KEY = 'total'.freeze

    Fact = Data.define(:code, :trip_on, :plate, :driver_code, :driver_name, :gross_cents, :net_cents, :loaded_km) do
      def measured?
        loaded_km.positive?
      end
    end

    Row = Data.define(:key, :label, :trips_count, :loaded_km, :gross, :net, :average, :net_average, :gross_per_km, :net_per_km) do
      extend ActiveModel::Naming
    end

    SORT_VALUES = {
      'label' => ->(row) { I18n.transliterate(row.label).downcase },
      'trips' => ->(row) { row.trips_count },
      'gross' => ->(row) { row.gross.cents },
      'net' => ->(row) { row.net.cents },
      'average' => ->(row) { row.average&.cents || -Float::INFINITY },
      'gross_per_km' => ->(row) { row.gross_per_km&.cents || -Float::INFINITY },
      'net_per_km' => ->(row) { row.net_per_km&.cents || -Float::INFINITY },
    }.freeze

    attr_reader :dimension, :period

    class << self
      def sanitize_dimension(dimension)
        DIMENSIONS.include?(dimension.to_s) ? dimension.to_s : DEFAULT_DIMENSION
      end
    end

    def initialize(manifests, dimension:, period:)
      @manifests = manifests
      @dimension = self.class.sanitize_dimension(dimension)
      @period = period
    end

    delegate :empty?, to: :period_facts

    def total
      @total ||= build_row(TOTAL_KEY, I18n.t('dashboards.trip.total'), period_facts)
    end

    def rows
      @rows ||= period_facts.group_by { |fact| key_for(fact) }
        .map { |key, grouped| build_row(key.to_s, label_for(key, grouped), grouped) }
        .sort_by { |row| [-row.gross.cents, row.label] }
    end

    def sorted_rows(column, direction)
      return rows unless SORT_VALUES.key?(column.to_s)

      sorted = rows.sort_by { |row| [SORT_VALUES.fetch(column.to_s).call(row), row.key] }

      direction.to_s == 'desc' ? sorted.reverse : sorted
    end

    def ranking_rows
      rows.first(RANKING_LIMIT)
    end

    def ranking_data
      series(ranking_rows.index_by { |row| ranking_label(row) }) { |row, value| row.public_send(value).to_f }
    end

    def per_km_ranking_data
      measured = ranking_rows.select(&:gross_per_km).sort_by { |row| -row.gross_per_km.cents }

      series(measured.index_by { |row| ranking_label(row) }) { |row, value| row.public_send(:"#{value}_per_km").to_f }
    end

    def months
      first_month = period.last.beginning_of_month.months_ago(HISTORY_MONTHS - 1)

      (0...HISTORY_MONTHS).map { |offset| first_month.months_since(offset) }
    end

    def weeks
      first_week = period.last.beginning_of_week(WEEK_START).weeks_ago(HISTORY_WEEKS - 1)

      (0...HISTORY_WEEKS).map { |offset| first_week.weeks_since(offset) }
    end

    def monthly_data
      series(history_labels(monthly_rows, :chart_month)) { |row, value| row.public_send(value).to_f }
    end

    def weekly_data
      series(history_labels(weekly_rows, :chart_week)) { |row, value| row.public_send(value).to_f }
    end

    def monthly_per_km_data
      series(history_labels(monthly_rows, :chart_month)) { |row, value| row.public_send(:"#{value}_per_km")&.to_f }
    end

    def weekly_per_km_data
      series(history_labels(weekly_rows, :chart_week)) { |row, value| row.public_send(:"#{value}_per_km")&.to_f }
    end

    private

    attr_reader :manifests

    def monthly_rows
      @monthly_rows ||= history_rows(months) { |fact| fact.trip_on.beginning_of_month }
    end

    def weekly_rows
      @weekly_rows ||= history_rows(weeks) { |fact| fact.trip_on.beginning_of_week(WEEK_START) }
    end

    def history_rows(starts, &)
      grouped = facts.group_by(&)

      starts.index_with { |start| build_row(start.iso8601, start.iso8601, grouped.fetch(start, [])) }
    end

    def series(labeled_rows)
      %i[gross net].map do |value|
        { name: I18n.t(value, scope: 'dashboards.trip'), data: labeled_rows.transform_values { |row| yield(row, value) } }
      end
    end

    def history_labels(history, format)
      history.to_h { |start, row| [I18n.t('dashboards.trip.chart_label', label: I18n.l(start, format:).capitalize, trips: row.trips_count), row] }
    end

    def ranking_label(row)
      I18n.t('dashboards.trip.chart_label', label: row.label, trips: row.trips_count)
    end

    def period_facts
      @period_facts ||= facts.select { |fact| period.cover?(fact.trip_on) }
    end

    def facts
      @facts ||= manifests.trips
        .where(Arel.sql(Atua::Manifest.trip_on_sql).between(facts_range))
        .joins(main_driver_join)
        .pluck(*fact_columns)
        .map do |code, trip_on, plate, driver_code, driver_name, gross_cents, net_cents, loaded_km|
          Fact.new(code, trip_on, plate, driver_code, driver_name, gross_cents.to_i, net_cents.to_i, loaded_km.to_d)
        end
    end

    def facts_range
      [period.first, months.first, weeks.first].min..period.last
    end

    def fact_columns
      [
        Atua::Manifest.arel_table[:code],
        Arel.sql(Atua::Manifest.trip_on_sql),
        Atua::Manifest.arel_table[:plate],
        Arel.sql('main_drivers.driver_code'),
        Arel.sql('main_drivers.driver_name'),
        Arel::Nodes::Grouping.new(Atua::Manifest.gross_freight),
        Arel::Nodes::Grouping.new(Atua::Manifest.net_freight),
        Arel::Nodes::Grouping.new(Arel.sql(Atua::Manifest.loaded_km_sql)),
      ]
    end

    def main_driver_join
      main_driver = Atua::Manifest.trip_documents.where.not(driver_code: nil)
        .reorder(freight_cents: :desc, id: :asc).limit(1).select(:driver_code, :driver_name)

      "LEFT JOIN LATERAL (#{main_driver.to_sql}) main_drivers ON TRUE"
    end

    def build_row(key, label, grouped)
      measured = grouped.select(&:measured?)
      measured_km = measured.sum(BigDecimal('0'), &:loaded_km)
      gross_cents = grouped.sum(&:gross_cents)
      net_cents = grouped.sum(&:net_cents)

      Row.new(
        key:,
        label:,
        trips_count: grouped.size,
        loaded_km: grouped.sum(BigDecimal('0'), &:loaded_km).round(2),
        gross: Money.from_cents(gross_cents),
        net: Money.from_cents(net_cents),
        average: divided(gross_cents, grouped.size),
        net_average: divided(net_cents, grouped.size),
        gross_per_km: divided(measured.sum(&:gross_cents), measured_km),
        net_per_km: divided(measured.sum(&:net_cents), measured_km),
      )
    end

    def divided(cents, divisor)
      Money.from_cents((cents.to_d / divisor).round(0, BigDecimal::ROUND_HALF_UP)) if divisor.positive?
    end

    def key_for(fact)
      dimension == 'vehicle' ? fact.plate : fact.driver_code
    end

    def label_for(key, grouped)
      label = if dimension == 'vehicle'
                key
              else
                driver_display_names[key].presence || grouped.filter_map(&:driver_name).first
              end

      label.presence || I18n.t(dimension, scope: 'dashboards.trip.none')
    end

    def driver_display_names
      @driver_display_names ||= Driver.where(tenant_id: manifests.unscope(:order, :select).select(:tenant_id))
        .where(code: period_facts.filter_map(&:driver_code).uniq).pluck(:code, :display_name).to_h
    end
  end
end
