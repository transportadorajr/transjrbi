module Dashboard
  class Freight
    DIMENSIONS = %w[customer_group vehicle driver origin macro_region].freeze
    DEFAULT_DIMENSION = 'customer_group'.freeze
    FREIGHT_LIST_DIMENSIONS = %w[vehicle driver].freeze
    HISTORY_MONTHS = 6
    MONTH_FORMAT = '%Y-%m'.freeze
    RANKING_LIMIT = 15
    TOTAL_KEY = 'total'.freeze
    COMPLEMENT_KIND = Atua::MapTransportDocumentsCommand::DOCUMENT_KINDS['CE']
    ABBREVIATED_DIMENSIONS = %w[driver customer_group].freeze
    NAME_CODE_PREFIX = /\A(\d+[\s-]+)+/
    NAME_PARTICLES = %w[DA DAS DE DO DOS E].freeze
    COMPANY_SUFFIX = %r{\A(LTDA|S/?A|S\.A|EIRELI|ME|EPP|SPE)\.?\z}i
    CHART_EXCLUDED_LABELS = { 'vehicle' => %w[INT6R00], 'driver' => ['JECI FERREIRA DE SOUZA JUNIOR'] }.freeze
    CHART_RENAMED_DRIVERS = { 'JECI FERREIRA DE SOUZA' => 'dashboards.freight.without_admission' }.freeze
    COLUMNS = %i[id manifest_code trip_plate reference_on issued_at loaded_km freight_cents freight_expenses_cents expenses_cents
                 toll_cents plate driver_code driver_name customer_group_id origin_city origin_state origin_macro_region_id].freeze
    ENTRY_ATTRIBUTES = %i[document_ids manifest_code weight reference_on loaded_km freight_cents freight_expenses_cents expenses_cents toll_cents
                          plate driver_code driver_name customer_group_id origin_city origin_state origin_macro_region_id].freeze

    Fact = Data.define(*COLUMNS) do
      def trip?
        manifest_code.present?
      end
    end

    Entry = Data.define(*ENTRY_ATTRIBUTES) do
      def trip?
        manifest_code.present?
      end

      def measured?
        trip? && loaded_km.positive?
      end

      def net_cents
        freight_cents - freight_expenses_cents - expenses_cents - toll_cents
      end
    end

    IssuedFact = Data.define(:issued_on, :freight_cents, :net_cents)
    MonthRow = Data.define(:month, :label, :gross, :net)

    Row = Data.define(:key, :label, :trips_count, :loaded_km, :gross, :freight_expenses, :expenses, :toll, :net, :gross_per_km, :net_per_km,
                      :share) do
      extend ActiveModel::Naming

      def confirmation_name
        label
      end
    end

    SORT_VALUES = {
      'label' => ->(row) { I18n.transliterate(row.label).downcase },
      'gross' => ->(row) { row.gross.cents },
      'net' => ->(row) { row.net.cents },
    }.freeze

    attr_reader :dimension, :period

    class << self
      def sanitize_dimension(dimension)
        DIMENSIONS.include?(dimension.to_s) ? dimension.to_s : DEFAULT_DIMENSION
      end
    end

    def initialize(documents, manifests:, dimension:, period:)
      @documents = documents
      @manifests = manifests
      @dimension = self.class.sanitize_dimension(dimension)
      @period = period
    end

    delegate :empty?, to: :entries

    def total
      @total ||= build_row(TOTAL_KEY, I18n.t('dashboards.freight.total'), entries)
    end

    def gross
      @gross ||= Money.from_cents(issued_documents.sum(table[:freight_cents]))
    end

    def net
      @net ||= gross - Money.from_cents(issued_freight_expenses_cents + issued_expenses_cents + issued_toll_cents)
    end

    def rows
      @rows ||= grouped_rows(entries)
    end

    def sorted_rows(column, direction)
      return rows unless SORT_VALUES.key?(column.to_s)

      sorted = rows.sort_by { |row| [SORT_VALUES.fetch(column.to_s).call(row), row.key] }

      direction.to_s == 'desc' ? sorted.reverse : sorted
    end

    def row_for(key)
      return total if key == TOTAL_KEY

      rows.find { |row| row.key == key.to_s }
    end

    def lists_freights?(key)
      FREIGHT_LIST_DIMENSIONS.include?(dimension) && key != TOTAL_KEY
    end

    def freights_for(key)
      documents.where(id: entries.select { |entry| row_key(key_for(entry)) == key.to_s }.flat_map(&:document_ids))
        .with_freight_totals
        .order(table[:issued_at].desc.nulls_last, id: :desc)
    end

    def ranking_rows
      @ranking_rows ||= rows.reject { |row| chart_excluded?(row) }
        .first(RANKING_LIMIT)
        .map { |row| row.with(label: chart_label(row.label)) }
    end

    def ranking_data
      labels = ranking_labels

      [
        { name: I18n.t('dashboards.freight.gross'), data: ranking_rows.zip(labels).to_h { |row, label| [label, row.gross.to_f] } },
        { name: I18n.t('dashboards.freight.net'), data: ranking_rows.zip(labels).to_h { |row, label| [label, row.net.to_f] } },
      ]
    end

    def history_period
      period.last.beginning_of_month.months_ago(HISTORY_MONTHS - 1)..period.last.end_of_month
    end

    def monthly_data
      months = issued_facts(history_period).group_by { |fact| fact.issued_on.beginning_of_month }
      labels = history_months.index_with { |month| month_label(month) }

      [
        { name: I18n.t('dashboards.freight.gross'), data: monthly_values(labels, months, &:freight_cents) },
        { name: I18n.t('dashboards.freight.net'), data: monthly_values(labels, months, &:net_cents) },
      ]
    end

    def billed_months
      history_months.index_with { |month| issued_months.include?(month) }
    end

    def month_row(value)
      month = history_months.find { |candidate| candidate.strftime(MONTH_FORMAT) == value.to_s }
      return unless month && issued_months.include?(month)

      facts = issued_facts(month..month.end_of_month)

      MonthRow.new(month:, label: month_label(month), gross: Money.from_cents(facts.sum(&:freight_cents)), net: Money.from_cents(facts.sum(&:net_cents)))
    end

    def month_freights(month)
      issued_documents(month..month.end_of_month)
        .with_freight_totals
        .order(table[:issued_at].desc.nulls_last, id: :desc)
    end

    private

    attr_reader :documents, :manifests

    def issued_months
      @issued_months ||= issued_facts(history_period).map { |fact| fact.issued_on.beginning_of_month }.uniq
    end

    def month_label(month)
      I18n.l(month, format: :chart_month).capitalize
    end

    def issued_documents(range = period)
      documents.active.not_canceled.by_period(range.first, range.last)
    end

    def issued_facts(range)
      issued_documents(range)
        .pluck(table[:issued_at], table[:freight_cents], Arel::Nodes::Grouping.new(Atua::TransportDocument.freight_expenses_total.arel),
               Arel::Nodes::Grouping.new(Atua::TransportDocument.expenses_total.arel), Atua::TransportDocument.freight_toll)
        .map do |issued_at, freight_cents, freight_expenses_cents, expenses_cents, toll_cents|
          IssuedFact.new(issued_on: issued_at.to_date, freight_cents:, net_cents: freight_cents - freight_expenses_cents - expenses_cents - toll_cents)
        end
    end

    def issued_freight_expenses_cents
      FreightExpense.where(transport_document_id: issued_documents.select(:id)).sum(:amount_cents)
    end

    def issued_expenses_cents
      Atua::Expense.active.freight.where(cost_object_id: issued_documents.select(:id)).sum(:total_cents)
    end

    def issued_toll_cents
      issued_documents.sum(Atua::TransportDocument.freight_toll)
    end

    def entries
      @entries ||= all_entries.select { |entry| period.cover?(entry.reference_on) }
    end

    def all_entries
      @all_entries ||= begin
        trips, complements = all_facts.partition(&:trip?)

        complements.map { |fact| complement_entry(fact) } +
          trips.group_by(&:manifest_code).values.flat_map { |trip_facts| trip_entries(trip_facts) }
      end
    end

    def grouped_rows(grouped_entries)
      grouped_entries.group_by { |entry| key_for(entry) }
        .map { |key, grouped| build_row(row_key(key), label_for(key, grouped), grouped) }
        .sort_by { |row| [-row.gross.cents, row.label] }
    end

    def row_key(key)
      Array(key).join('|')
    end

    def chart_excluded?(row)
      CHART_EXCLUDED_LABELS.fetch(dimension, []).include?(normalized(row.label))
    end

    def chart_label(label)
      renamed = CHART_RENAMED_DRIVERS[normalized(label)] if dimension == 'driver'

      renamed ? I18n.t(renamed) : label
    end

    def normalized(value)
      value.to_s.squish.upcase
    end

    def complement_entry(fact)
      Entry.new(
        document_ids: [fact.id], manifest_code: nil, weight: BigDecimal('0'), reference_on: fact.reference_on, loaded_km: BigDecimal('0'), **money_of([fact]),
        plate: fact.plate, driver_code: fact.driver_code, driver_name: fact.driver_name, customer_group_id: fact.customer_group_id,
        origin_city: fact.origin_city, origin_state: fact.origin_state, origin_macro_region_id: fact.origin_macro_region_id
      )
    end

    def trip_entries(trip_facts)
      trip = trip_facts.first
      main = trip_facts.max_by { |fact| [fact.freight_cents.to_i, -fact.id] }
      first_loading = trip_facts.min_by { |fact| [fact.issued_at.to_i, fact.id] }

      slices_of(trip_facts).map do |slice, weight|
        Entry.new(
          document_ids: slice.map(&:id), manifest_code: trip.manifest_code, weight:, reference_on: trip.reference_on, loaded_km: trip.loaded_km.to_d * weight,
          **money_of(slice), plate: trip.trip_plate, driver_code: main.driver_code, driver_name: main.driver_name,
          customer_group_id: slice.first.customer_group_id, origin_city: first_loading.origin_city,
          origin_state: first_loading.origin_state, origin_macro_region_id: first_loading.origin_macro_region_id
        )
      end
    end

    def slices_of(trip_facts)
      return { trip_facts => BigDecimal('1') } unless dimension == 'customer_group'

      slices = trip_facts.group_by(&:customer_group_id).values
      trip_cents = freight_of(trip_facts)

      slices.index_with { |slice| trip_cents.zero? ? BigDecimal('1') / slices.size : freight_of(slice).to_d / trip_cents }
    end

    def money_of(facts)
      {
        freight_cents: freight_of(facts),
        freight_expenses_cents: facts.sum { |fact| fact.freight_expenses_cents.to_i },
        expenses_cents: facts.sum { |fact| fact.expenses_cents.to_i },
        toll_cents: facts.sum { |fact| fact.toll_cents.to_i },
      }
    end

    def freight_of(facts)
      facts.sum { |fact| fact.freight_cents.to_i }
    end

    def all_facts
      documents.active.not_canceled
        .left_joins(:taker)
        .joins(first_trip_join)
        .where(first_trips[:manifest_code].not_eq(nil).or(table[:document_kind].eq(COMPLEMENT_KIND)))
        .where(Arel.sql(reference_on_sql).between(period))
        .pluck(*fact_columns)
        .map { |values| Fact.new(*values) }
    end

    def fact_columns
      [
        table[:id],
        Arel.sql('first_trips.manifest_code'),
        Arel.sql('first_trips.plate'),
        Arel.sql(reference_on_sql),
        table[:issued_at],
        Arel.sql('first_trips.loaded_km'),
        table[:freight_cents],
        Arel::Nodes::Grouping.new(Atua::TransportDocument.freight_expenses_total.arel),
        Arel::Nodes::Grouping.new(Atua::TransportDocument.expenses_total.arel),
        Atua::TransportDocument.freight_toll,
        table[:plate],
        table[:driver_code],
        table[:driver_name],
        Atua::Customer.arel_table[:customer_group_id],
        table[:origin_city],
        table[:origin_state],
        table[:origin_macro_region_id],
      ]
    end

    def reference_on_sql
      "COALESCE(first_trips.trip_on, #{table.name}.posted_on)"
    end

    def first_trip_join
      <<~SQL.squish
        LEFT JOIN LATERAL (
          SELECT atua_manifests.code AS manifest_code, atua_manifests.plate AS plate, #{Atua::Manifest.trip_on_sql} AS trip_on,
                 (#{Atua::Manifest.loaded_km_sql}) AS loaded_km
          FROM atua_manifest_documents
          INNER JOIN atua_manifests ON atua_manifests.tenant_id = atua_manifest_documents.tenant_id
            AND atua_manifests.code = atua_manifest_documents.manifest_code
          WHERE atua_manifest_documents.tenant_id = #{table.name}.tenant_id
            AND atua_manifest_documents.transport_document_number = #{table.name}.number
            AND atua_manifest_documents.transport_document_series = #{table.name}.series
            AND atua_manifest_documents.branch_name = #{table.name}.branch_name
            AND atua_manifest_documents.removed_from_atua_at IS NULL
            AND atua_manifests.id IN (#{manifests.trips.select(:id).to_sql})
          ORDER BY #{Atua::Manifest.trip_at.to_sql}, atua_manifests.code
          LIMIT 1
        ) first_trips ON TRUE
      SQL
    end

    def build_row(key, label, grouped)
      measured = grouped.select(&:measured?)
      measured_km = measured.sum(BigDecimal('0'), &:loaded_km)
      gross_cents = grouped.sum(&:freight_cents)
      freight_expenses_cents = grouped.sum(&:freight_expenses_cents)
      expenses_cents = grouped.sum(&:expenses_cents)
      toll_cents = grouped.sum(&:toll_cents)

      Row.new(
        key:,
        label:,
        trips_count: grouped.sum(BigDecimal('0'), &:weight).round(2),
        loaded_km: grouped.sum(BigDecimal('0'), &:loaded_km).round(2),
        gross: Money.from_cents(gross_cents),
        freight_expenses: Money.from_cents(freight_expenses_cents),
        expenses: Money.from_cents(expenses_cents),
        toll: Money.from_cents(toll_cents),
        net: Money.from_cents(gross_cents - freight_expenses_cents - expenses_cents - toll_cents),
        gross_per_km: per_km(measured.sum(&:freight_cents), measured_km),
        net_per_km: per_km(measured.sum(&:net_cents), measured_km),
        share: share_of(gross_cents),
      )
    end

    def per_km(cents, distance)
      Money.from_cents((cents / distance).round(0, BigDecimal::ROUND_HALF_UP)) if distance.positive?
    end

    def share_of(cents)
      total_cents = entries.sum(&:freight_cents)
      return BigDecimal('0') if total_cents.zero?

      (cents.to_d * 100 / total_cents).round(1)
    end

    def key_for(entry)
      case dimension
      when 'vehicle' then entry.plate.presence
      when 'driver' then entry.driver_code
      when 'customer_group' then entry.customer_group_id
      when 'origin' then [entry.origin_city.presence, entry.origin_state.presence]
      when 'macro_region' then entry.origin_macro_region_id
      end
    end

    def label_for(key, grouped)
      label = case dimension
              when 'vehicle' then key
              when 'driver' then grouped.filter_map { |entry| entry.driver_name.presence }.first
              when 'customer_group' then customer_group_names[key]
              when 'origin' then origin_label(*key)
              when 'macro_region' then macro_region_names[key]
              end

      label.presence || I18n.t(dimension, scope: 'dashboards.freight.none')
    end

    def ranking_labels
      return ranking_rows.map(&:label) unless ABBREVIATED_DIMENSIONS.include?(dimension)

      abbreviated = ranking_rows.map { |row| ranking_label(row.label) }
      repeated = abbreviated.tally.select { |_, count| count > 1 }.keys

      ranking_rows.zip(abbreviated).map { |row, label| repeated.include?(label) ? row.label : label }
    end

    def ranking_label(name)
      named_customer_group?(name) ? name : abbreviate(name)
    end

    def named_customer_group?(name)
      dimension == 'customer_group' && named_customer_groups.include?(name)
    end

    def named_customer_groups
      @named_customer_groups ||= CustomerGroup.with_terms.where(id: entries.filter_map(&:customer_group_id).uniq).pluck(:name)
    end

    def abbreviate(name)
      words = name.sub(NAME_CODE_PREFIX, '').split.grep_v(COMPANY_SUFFIX)
      return name if words.empty?
      return words.join(' ') if words.size <= 2

      initials = words[1...-1].reject { |word| NAME_PARTICLES.include?(word.upcase) }
        .map { |word| word.match?(/\A[[:alpha:]]/) ? "#{word[0]}." : word }

      [words.first, *initials, words.last].join(' ')
    end

    def origin_label(city, state)
      return city if city.blank? || state.blank?

      I18n.t('tax.city', city:, state:)
    end

    def customer_group_names
      @customer_group_names ||= CustomerGroup.where(id: entries.filter_map(&:customer_group_id).uniq).pluck(:id, :name).to_h
    end

    def macro_region_names
      @macro_region_names ||= MacroRegion.where(id: entries.filter_map(&:origin_macro_region_id).uniq).pluck(:id, :name).to_h
    end

    def history_months
      first_month = history_period.first.beginning_of_month

      (0...HISTORY_MONTHS).map { |offset| first_month.months_since(offset) }
    end

    def monthly_values(labels, months, &)
      labels.to_h { |month, label| [label, Money.from_cents(months.fetch(month, []).sum(&)).to_f] }
    end

    def first_trips
      Arel::Table.new(:first_trips)
    end

    def table
      Atua::TransportDocument.arel_table
    end
  end
end
