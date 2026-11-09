module Dashboard
  class Trip
    DIMENSIONS = %w[driver vehicle manifest].freeze
    DEFAULT_DIMENSION = 'driver'.freeze
    DEFAULT_SORT = 'net_per_km'.freeze
    HIGHLIGHT_COLUMNS = %w[gross_per_km net_per_km].freeze
    HIGHLIGHT_LIMIT = 3
    MAX_LOADED_KM = 5_000
    HISTORY_MONTHS = 6
    HISTORY_WEEKS = 12
    WEEK_START = :sunday
    RANKING_LIMIT = 15
    TOTAL_KEY = 'total'.freeze
    FEATURE = :trips_dashboard

    Fact = Data.define(:id, :code, :number, :trip_on, :plate, :driver_code, :driver_name, :gross_cents, :net_cents, :loaded_km) do
      def measured?
        loaded_km.positive? && loaded_km <= MAX_LOADED_KM
      end
    end

    Row = Data.define(:key, :label, :detail, :manifest_id, :trips_count, :loaded_km, :gross, :expenses, :net, :average, :net_average,
                      :gross_per_km, :net_per_km) do
      extend ActiveModel::Naming
    end

    SORT_VALUES = {
      'label' => ->(row) { I18n.transliterate(row.label).downcase },
      'trips' => ->(row) { row.trips_count },
      'gross' => ->(row) { row.gross.cents },
      'expenses' => ->(row) { row.expenses.cents },
      'net' => ->(row) { row.net.cents },
      'average' => ->(row) { row.average&.cents || -Float::INFINITY },
      'gross_per_km' => ->(row) { row.gross_per_km&.cents || -Float::INFINITY },
      'net_per_km' => ->(row) { row.net_per_km&.cents || -Float::INFINITY },
    }.freeze

    attr_reader :dimension, :period

    class << self
      def enabled?(tenant)
        Flipper.enabled?(FEATURE, tenant)
      end

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

    def table_total
      @table_total ||= build_row(TOTAL_KEY, I18n.t('dashboards.trip.total'), ranked_facts)
    end

    def rows
      @rows ||= ranked_facts.group_by { |fact| key_for(fact) }
        .map { |key, grouped| row_for(key, grouped) }
        .sort_by { |row| [-row.gross.cents, row.label] }
    end

    def sorted_rows(column, direction)
      return sorted_rows(DEFAULT_SORT, 'desc') unless SORT_VALUES.key?(column.to_s)

      sorted = rows.sort_by { |row| [SORT_VALUES.fetch(column.to_s).call(row), row.key] }

      direction.to_s == 'desc' ? sorted.reverse : sorted
    end

    def highlights(column)
      indicator = HIGHLIGHT_COLUMNS.include?(column.to_s) ? column.to_s : DEFAULT_SORT
      ranked = rows.select { |row| row.public_send(indicator) }.sort_by { |row| [-row.public_send(indicator).cents, row.key] }
      count = [HIGHLIGHT_LIMIT, ranked.size / 2].min

      ranked.first(count).to_h { |row| [row.key, :best] }.merge(ranked.last(count).to_h { |row| [row.key, :worst] })
    end

    def per_km_base
      @per_km_base ||= begin
        measured, excluded = period_facts.partition(&:measured?)

        PerKmBase.new(gross: Money.from_cents(measured.sum(&:gross_cents)), net: Money.from_cents(measured.sum(&:net_cents)),
                      loaded_km: measured.sum(BigDecimal('0'), &:loaded_km).round(2), excluded_count: excluded.size,
                      excluded_gross: Money.from_cents(excluded.sum(&:gross_cents)), excluded_net: Money.from_cents(excluded.sum(&:net_cents)))
      end
    end

    def unmeasured_trips
      @unmeasured_trips ||= period_facts.reject(&:measured?).sort_by { |fact| [fact.trip_on, fact.code] }
    end

    def ranking_rows
      rows.first(RANKING_LIMIT)
    end

    def ranking_data
      series(ranking_rows.index_by { |row| ranking_label(row) }) { |row, value| row.public_send(value).to_f }
    end

    def per_km_ranking_data
      measured = rows.select(&:net_per_km).sort_by { |row| [-row.net_per_km.cents, row.key] }.first(RANKING_LIMIT)

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
      return row.label if dimension == 'manifest'

      I18n.t('dashboards.trip.chart_label', label: row.label, trips: row.trips_count)
    end

    def period_facts
      @period_facts ||= facts.select { |fact| period.cover?(fact.trip_on) }
    end

    def ranked_facts
      @ranked_facts ||= dimension == 'manifest' ? period_facts.select(&:measured?) : period_facts
    end

    def facts
      @facts ||= manifests.trips
        .where(Arel.sql(Atua::Manifest.trip_on_sql).between(facts_range))
        .where(Atua::Manifest.first_trip_documents.arel.exists)
        .joins(main_driver_join)
        .pluck(*fact_columns)
        .map do |id, code, number, trip_on, plate, driver_code, driver_name, gross_cents, net_cents, loaded_km|
          Fact.new(id, code, number, trip_on, plate, driver_code, driver_name, gross_cents.to_i, net_cents.to_i, loaded_km.to_d)
        end
    end

    def facts_range
      [period.first, months.first, weeks.first].min..period.last
    end

    def fact_columns
      [
        Atua::Manifest.arel_table[:id],
        Atua::Manifest.arel_table[:code],
        Atua::Manifest.arel_table[:number],
        Arel.sql(Atua::Manifest.trip_on_sql),
        Atua::Manifest.arel_table[:plate],
        Arel.sql('main_drivers.driver_code'),
        Arel.sql('main_drivers.driver_name'),
        Arel::Nodes::Grouping.new(Atua::Manifest.gross_freight(Atua::Manifest.first_trip_documents)),
        Arel::Nodes::Grouping.new(Atua::Manifest.net_freight(Atua::Manifest.first_trip_documents)),
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
        detail: nil,
        manifest_id: nil,
        trips_count: grouped.size,
        loaded_km: grouped.sum(BigDecimal('0'), &:loaded_km).round(2),
        gross: Money.from_cents(gross_cents),
        expenses: Money.from_cents(gross_cents - net_cents),
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

    def row_for(key, grouped)
      row = build_row(key.to_s, label_for(key, grouped), grouped)
      return row unless dimension == 'manifest'

      fact = grouped.first
      row.with(detail: I18n.t('dashboards.trip.manifest_detail', plate: fact.plate, date: I18n.l(fact.trip_on)), manifest_id: fact.id)
    end

    def key_for(fact)
      case dimension
      when 'vehicle' then fact.plate
      when 'manifest' then fact.id
      else fact.driver_code
      end
    end

    def label_for(key, grouped)
      label = case dimension
              when 'vehicle' then key
              when 'manifest' then grouped.first.number
              else driver_display_names[key].presence || grouped.filter_map(&:driver_name).first
              end

      label.presence || I18n.t(dimension, scope: 'dashboards.trip.none')
    end

    def driver_display_names
      @driver_display_names ||= Driver.where(tenant_id: manifests.unscope(:order, :select).select(:tenant_id))
        .where(code: period_facts.filter_map(&:driver_code).uniq).pluck(:code, :display_name).to_h
    end
  end
end
