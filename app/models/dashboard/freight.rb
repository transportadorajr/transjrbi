module Dashboard
  class Freight
    DIMENSIONS = %w[vehicle driver customer_group origin].freeze
    DEFAULT_DIMENSION = 'vehicle'.freeze
    HISTORY_MONTHS = 6
    RANKING_LIMIT = 15
    COMPLEMENT_KIND = Atua::MapTransportDocumentsCommand::DOCUMENT_KINDS['CE']
    COLUMNS = %i[manifest_code reference_on loaded_km empty_km freight_cents freight_expenses_cents expenses_cents plate
                 trailer_plate driver_code driver_name customer_group_id origin_city origin_state].freeze

    Fact = Data.define(*COLUMNS) do
      def trip?
        manifest_code.present?
      end

      def measured?
        trip? && loaded_km.to_d.positive?
      end

      def net_cents
        freight_cents.to_i - freight_expenses_cents.to_i - expenses_cents.to_i
      end
    end

    Row = Data.define(:label, :trips_count, :loaded_km, :empty_km, :gross, :freight_expenses, :expenses, :net, :gross_per_km,
                      :net_per_km, :share)

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

    delegate :empty?, to: :facts

    def total
      @total ||= build_row(I18n.t('dashboards.freight.total'), facts)
    end

    def rows
      @rows ||= facts.group_by { |fact| key_for(fact) }
        .map { |key, grouped| build_row(label_for(key, grouped), grouped) }
        .sort_by { |row| [-row.gross.cents, row.label] }
    end

    def ranking_rows
      rows.first(RANKING_LIMIT)
    end

    def ranking_data
      [
        { name: I18n.t('dashboards.freight.gross'), data: ranking_rows.to_h { |row| [row.label, row.gross.to_f] } },
        { name: I18n.t('dashboards.freight.net'), data: ranking_rows.to_h { |row| [row.label, row.net.to_f] } },
      ]
    end

    def history_period
      period.last.beginning_of_month.months_ago(HISTORY_MONTHS - 1)..period.last
    end

    def monthly_data
      months = history_facts.group_by { |fact| fact.reference_on.beginning_of_month }
      labels = history_months.index_with { |month| I18n.l(month, format: :chart_month).capitalize }

      [
        { name: I18n.t('dashboards.freight.gross'), data: monthly_values(labels, months, &:freight_cents) },
        { name: I18n.t('dashboards.freight.net'), data: monthly_values(labels, months, &:net_cents) },
      ]
    end

    private

    attr_reader :documents, :manifests

    def facts
      @facts ||= all_facts.select { |fact| period.cover?(fact.reference_on) }
    end

    def history_facts
      all_facts.select { |fact| history_period.cover?(fact.reference_on) }
    end

    def all_facts
      @all_facts ||= documents.active.not_canceled
        .left_joins(:taker)
        .joins(first_trip_join)
        .where("first_trips.manifest_code IS NOT NULL OR #{table.name}.document_kind = ?", COMPLEMENT_KIND)
        .where("#{reference_on_sql} BETWEEN ? AND ?", fetched_period.first, fetched_period.last)
        .pluck(*fact_columns)
        .map { |values| Fact.new(*values) }
    end

    def fetched_period
      [period.first, history_period.first].min..period.last
    end

    def fact_columns
      [
        Arel.sql('first_trips.manifest_code'),
        Arel.sql(reference_on_sql),
        Arel.sql('first_trips.loaded_km'),
        Arel.sql('first_trips.empty_km'),
        table[:freight_cents],
        Arel::Nodes::Grouping.new(freight_expenses_total.arel),
        Arel::Nodes::Grouping.new(expenses_total.arel),
        table[:plate],
        table[:trailer_plate],
        table[:driver_code],
        table[:driver_name],
        Atua::Customer.arel_table[:customer_group_id],
        table[:origin_city],
        table[:origin_state],
      ]
    end

    def reference_on_sql
      "COALESCE(first_trips.trip_on, #{table.name}.posted_on)"
    end

    def first_trip_join
      <<~SQL.squish
        LEFT JOIN LATERAL (
          SELECT atua_manifests.code AS manifest_code, #{trip_on_sql} AS trip_on,
                 (#{loaded_km_sql}) AS loaded_km, (#{empty_km_sql}) AS empty_km
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

    def trip_on_sql
      started_on = "(atua_manifests.trip_started_at AT TIME ZONE 'UTC' AT TIME ZONE #{connection.quote(Time.zone.tzinfo.name)})::date"

      "COALESCE(#{started_on}, atua_manifests.departure_on, atua_manifests.issued_on)"
    end

    def loaded_km_sql
      <<~SQL.squish
        SELECT MAX(GREATEST(COALESCE(distances.calculated_distance_km, 0), COALESCE(distances.document_distance_km, 0)))
        FROM atua_manifest_documents distances
        WHERE distances.tenant_id = atua_manifests.tenant_id AND distances.manifest_code = atua_manifests.code
          AND distances.removed_from_atua_at IS NULL
      SQL
    end

    def empty_km_sql
      EmptyLeg.calculated.select(:distance_km)
        .where(EmptyLeg.arel_table[:tenant_id].eq(Atua::Manifest.arel_table[:tenant_id]))
        .where(EmptyLeg.arel_table[:next_manifest_code].eq(Atua::Manifest.arel_table[:code]))
        .to_sql
    end

    def freight_expenses_total
      FreightExpense.where(FreightExpense.arel_table[:transport_document_id].eq(table[:id]))
        .select(sum_of(FreightExpense.arel_table[:amount_cents]))
    end

    def expenses_total
      Atua::Expense.active.freight.where(Atua::Expense.arel_table[:cost_object_id].eq(table[:id]))
        .select(sum_of(Atua::Expense.arel_table[:total_cents]))
    end

    def sum_of(column)
      Arel::Nodes::NamedFunction.new('COALESCE', [column.sum, Arel::Nodes.build_quoted(0)])
    end

    def build_row(label, grouped)
      trips = grouped.select(&:trip?).uniq(&:manifest_code)
      loaded_km = trips.sum(BigDecimal('0')) { |fact| fact.loaded_km.to_d }
      measured = grouped.select(&:measured?)
      gross_cents = grouped.sum { |fact| fact.freight_cents.to_i }
      freight_expenses_cents = grouped.sum { |fact| fact.freight_expenses_cents.to_i }
      expenses_cents = grouped.sum { |fact| fact.expenses_cents.to_i }

      Row.new(
        label:,
        trips_count: trips.size,
        loaded_km:,
        empty_km: trips.sum(BigDecimal('0')) { |fact| fact.empty_km.to_d },
        gross: Money.from_cents(gross_cents),
        freight_expenses: Money.from_cents(freight_expenses_cents),
        expenses: Money.from_cents(expenses_cents),
        net: Money.from_cents(gross_cents - freight_expenses_cents - expenses_cents),
        gross_per_km: per_km(measured.sum { |fact| fact.freight_cents.to_i }, loaded_km),
        net_per_km: per_km(measured.sum(&:net_cents), loaded_km),
        share: share_of(gross_cents),
      )
    end

    def per_km(cents, distance)
      Money.from_cents((cents / distance).round(0, BigDecimal::ROUND_HALF_UP)) if distance.positive?
    end

    def share_of(cents)
      total_cents = facts.sum { |fact| fact.freight_cents.to_i }
      return BigDecimal('0') if total_cents.zero?

      (cents.to_d * 100 / total_cents).round(1)
    end

    def key_for(fact)
      case dimension
      when 'vehicle' then [fact.plate.presence, fact.trailer_plate.presence]
      when 'driver' then fact.driver_code
      when 'customer_group' then fact.customer_group_id
      when 'origin' then [fact.origin_city.presence, fact.origin_state.presence]
      end
    end

    def label_for(key, grouped)
      label = case dimension
              when 'vehicle' then key.compact.join(' + ')
              when 'driver' then grouped.filter_map { |fact| fact.driver_name.presence }.first
              when 'customer_group' then customer_group_names[key]
              when 'origin' then origin_label(*key)
              end

      label.presence || I18n.t(dimension, scope: 'dashboards.freight.none')
    end

    def origin_label(city, state)
      return city if city.blank? || state.blank?

      I18n.t('tax.city', city:, state:)
    end

    def customer_group_names
      @customer_group_names ||= CustomerGroup.where(id: facts.filter_map(&:customer_group_id).uniq).pluck(:id, :name).to_h
    end

    def history_months
      first_month = history_period.first.beginning_of_month

      (0...HISTORY_MONTHS).map { |offset| first_month.months_since(offset) }
    end

    def monthly_values(labels, months, &)
      labels.to_h { |month, label| [label, Money.from_cents(months.fetch(month, []).sum(&)).to_f] }
    end

    def table
      Atua::TransportDocument.arel_table
    end

    def connection
      Atua::TransportDocument.connection
    end
  end
end
