module Dashboard
  class Export
    WEEK_START = FreightBillingFilterForm::WEEK_START
    HISTORY_MONTHS = 6
    HISTORY_WEEKS = 5
    TOTAL_KEY = 'total'.freeze
    NO_GROUP_KEY = 'none'.freeze
    KEY_SEPARATOR = '|'.freeze

    Row = Data.define(:key, :customer_group, :plant, :country, :tons, :loadings_count, :documents_count, :share) do
      extend ActiveModel::Naming

      def label
        [customer_group, plant, country].uniq.join(' · ')
      end

      def confirmation_name
        label
      end
    end

    Comparison = Data.define(:current_period, :previous_period, :current_tons, :previous_tons, :current_loadings, :previous_loadings) do
      def variation
        return if previous_tons.zero?

        ((current_tons - previous_tons) / previous_tons * 100).round(1)
      end
    end

    ShortcutSummary = Data.define(:shortcut, :week, :month)

    attr_reader :period, :today

    def initialize(documents:, manifests:, customers:, plants:, period:, filters: {}, shortcuts: [], today: Date.current)
      @facts_source = ExportFacts.new(documents:, manifests:, customers:, plants:)
      @shortcuts = shortcuts
      @customers = customers
      @plants = plants
      @period = period
      @filters = filters.to_h.symbolize_keys.compact_blank
      @today = today
    end

    delegate :empty?, to: :period_facts

    def total
      @total ||= build_row(TOTAL_KEY, period_facts, label: I18n.t('dashboards.export.total'))
    end

    def rows
      @rows ||= period_facts.group_by { |fact| row_key(fact) }
        .map { |key, grouped| build_row(key, grouped) }
        .sort_by { |row| [-row.tons, row.customer_group, row.plant, row.country] }
    end

    def find_row(key)
      return total if key.to_s == TOTAL_KEY

      rows.find { |row| row.key == key.to_s }
    end

    def documents_for(key)
      return if find_row(key).nil?
      return period_facts if key.to_s == TOTAL_KEY

      period_facts.select { |fact| row_key(fact) == key.to_s }
    end

    def week_comparison
      @week_comparison ||= comparison(today.beginning_of_week(WEEK_START)..today, 1.week)
    end

    def month_comparison
      @month_comparison ||= comparison(today.beginning_of_month..today, 1.month)
    end

    def shortcut_summaries
      @shortcut_summaries ||= shortcuts.map do |shortcut|
        shortcut_facts = all_facts.select { |fact| shortcut.matches?(fact) }

        ShortcutSummary.new(shortcut:, week: comparison(today.beginning_of_week(WEEK_START)..today, 1.week, shortcut_facts),
                            month: comparison(today.beginning_of_month..today, 1.month, shortcut_facts))
      end
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
      history_series(months, :chart_month) { |fact| fact.trip_on.beginning_of_month }
    end

    def weekly_data
      history_series(weeks, :chart_week) { |fact| fact.trip_on.beginning_of_week(WEEK_START) }
    end

    def customer_group_options
      ids = facts.filter_map(&:customer_group_id).uniq

      customer_group_names.slice(*ids).sort_by { |_id, name| I18n.transliterate(name).downcase }.map { |id, name| [name, id] }
    end

    def plant_options
      registered = plants.order(:name, :id).map { |plant| [plant.name, "#{ExportFacts::PLANT_PREFIX}-#{plant.id}"] }

      (registered + facts.map { |fact| [fact.plant_label, fact.plant_key] }).uniq(&:last).sort_by { |label, _key| I18n.transliterate(label).downcase }
    end

    def country_options
      Atua::Customer.enum_options_for_select(:country_type) + [[country_label(ExportFacts::UNKNOWN_COUNTRY), ExportFacts::UNKNOWN_COUNTRY]]
    end

    def customer_group_label(customer_group_id)
      customer_group_names[customer_group_id] || I18n.t('dashboards.export.no_customer_group')
    end

    def customer_group_names
      @customer_group_names ||= CustomerGroup.where(id: customers.where.not(customer_group_id: nil).select(:customer_group_id))
        .pluck(:id, :name).to_h
    end

    def country_label(country)
      return I18n.t('dashboards.export.unknown_country') if country.nil? || country == ExportFacts::UNKNOWN_COUNTRY

      Atua::Customer.human_enum_name(:country_type, country)
    end

    private

    attr_reader :facts_source, :customers, :plants, :filters, :shortcuts

    def all_facts
      @all_facts ||= facts_source.call(facts_range)
    end

    def facts
      @facts ||= filtered(all_facts)
    end

    def period_facts
      @period_facts ||= facts.select { |fact| period.cover?(fact.trip_on) }
    end

    def facts_range
      first = [period.first, months.first, weeks.first, week_comparison_start.weeks_ago(1), today.prev_month.beginning_of_month].min

      first..[period.last, today].max
    end

    def week_comparison_start
      today.beginning_of_week(WEEK_START)
    end

    def filtered(all_facts)
      all_facts.select do |fact|
        matches?(:customer_group_id, fact.customer_group_id) && matches?(:plant, fact.plant_key) && matches?(:country, fact.country) &&
          (!filters.key?(:shortcut) || filters[:shortcut].matches?(fact))
      end
    end

    def matches?(filter, value)
      !filters.key?(filter) || filters[filter].to_s == value.to_s
    end

    def comparison(current_period, length, source = facts)
      previous_period = (current_period.first - length)..(current_period.last - length)
      current = source.select { |fact| current_period.cover?(fact.trip_on) }
      previous = source.select { |fact| previous_period.cover?(fact.trip_on) }

      Comparison.new(current_period:, previous_period:, current_tons: tons_of(current), previous_tons: tons_of(previous),
                     current_loadings: loadings_of(current), previous_loadings: loadings_of(previous))
    end

    def history_series(starts, format, &)
      grouped = facts.group_by(&)
      history = starts.index_with { |start| grouped.fetch(start, []) }

      countries_by_tons(history.values.flatten).map do |country|
        data = history.to_h do |start, grouped_facts|
          [I18n.l(start, format:).capitalize, tons_of(grouped_facts.select { |fact| fact.country == country }).to_f]
        end

        { name: country_label(country), data: }
      end
    end

    def countries_by_tons(history_facts)
      history_facts.group_by(&:country).sort_by { |country, grouped| [-tons_of(grouped), country] }.map(&:first)
    end

    def build_row(key, grouped, label: nil)
      sample = grouped.first

      Row.new(
        key:,
        customer_group: label || customer_group_label(sample&.customer_group_id),
        plant: label || sample&.plant_label,
        country: label || country_label(sample&.country),
        tons: tons_of(grouped),
        loadings_count: loadings_of(grouped),
        documents_count: grouped.size,
        share: share_of(tons_of(grouped)),
      )
    end

    def row_key(fact)
      [fact.customer_group_id || NO_GROUP_KEY, fact.plant_key, fact.country].join(KEY_SEPARATOR)
    end

    def tons_of(grouped)
      grouped.sum(BigDecimal('0'), &:tons).round(3)
    end

    def loadings_of(grouped)
      grouped.map(&:manifest_code).uniq.size
    end

    def share_of(tons)
      total_tons = tons_of(period_facts)
      return BigDecimal('0') if total_tons.zero?

      (tons / total_tons * 100).round(1)
    end
  end
end
