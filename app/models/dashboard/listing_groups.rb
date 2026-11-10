module Dashboard
  class ListingGroups
    DIMENSIONS = %w[customer_group customer vehicle driver].freeze
    FILTER_PARAMS = { 'customer_group' => 'customer_group_id', 'customer' => 'customer_code', 'vehicle' => 'plate', 'driver' => 'driver_code' }.freeze

    Row = Data.define(:key, :label, :count, :gross, :net, :durations) do
      def filterable?
        !key.nil?
      end
    end

    attr_reader :dimension

    class << self
      def sanitize_dimension(dimension)
        DIMENSIONS.include?(dimension.to_s) ? dimension.to_s : nil
      end

      def for_transport_documents(documents, dimension:, net:)
        new(documents.unscope(:order, :select), dimension:, net:, counted: Atua::TransportDocument.arel_table[:id],
                                                plate: Atua::TransportDocument.arel_table[:plate])
      end

      def for_manifests(manifests, dimension:, net:)
        documents = Atua::TransportDocument.active.not_canceled.without_ce.joins(manifest_documents: :manifest)
          .merge(Atua::ManifestDocument.active).where(atua_manifests: { id: manifests.unscope(:order, :select).select(:id) })

        new(documents, dimension:, net:, counted: Atua::Manifest.arel_table[:id], plate: Atua::Manifest.arel_table[:plate], durations: true)
      end
    end

    def initialize(documents, dimension:, net:, counted:, plate:, durations: false)
      @documents = documents
      @dimension = self.class.sanitize_dimension(dimension)
      @net = net
      @counted = counted
      @plate = plate
      @durations = durations
    end

    def durations?
      @durations
    end

    def grouped?
      !dimension.nil?
    end

    def filter_param
      FILTER_PARAMS.fetch(dimension)
    end

    def rows
      @rows ||= grouped_documents.group(key_column).pluck(key_column, label_column, *totals_columns)
        .map { |key, label, count, gross, net| build_row(key, label, count, gross, net, durations_by_key[key]) }
        .sort_by { |row| [-row.gross.cents, I18n.transliterate(row.label.to_s).downcase] }
    end

    def total
      @total ||= begin
        count, gross, net = documents.pick(*totals_columns)

        build_row(nil, I18n.t('dashboards.listing_groups.total'), count, gross, net, total_durations)
      end
    end

    private

    attr_reader :documents, :counted, :plate

    def build_row(key, label, count, gross, net, durations)
      Row.new(key: key&.to_s, label: label.presence || I18n.t(dimension, scope: 'dashboards.listing_groups.none'), count: count.to_i,
              gross: Money.from_cents(gross.to_i), net: @net ? Money.from_cents(net.to_i) : nil, durations:)
    end

    def durations_by_key
      return {} unless durations?

      @durations_by_key ||= duration_facts(key_column).group_by(&:first)
        .transform_values { |facts| TripDurations.new(facts.map(&:last)) }
    end

    def total_durations
      return unless durations?

      TripDurations.new(duration_facts.map(&:last))
    end

    def duration_facts(key = nil)
      manifest_id = Atua::Manifest.arel_table[:id]
      columns = [key, manifest_id].compact
      relation = key ? grouped_documents : documents

      relation.group(*columns).pluck(*columns, *duration_columns).map do |*keys, seconds, in_progress, net|
        [keys.first, TripDurations.build_fact(seconds, net, in_progress)]
      end
    end

    def duration_columns
      [Arel::Nodes::NamedFunction.new('MAX', [Arel.sql(Atua::Manifest.duration_seconds_sql)]),
       Arel::Nodes::NamedFunction.new('BOOL_OR', [Arel.sql(Atua::Manifest.in_progress_sql)]),
       Atua::TransportDocument.sum_or_zero(Atua::TransportDocument.net_freight)]
    end

    def totals_columns
      columns = [counted.count(true), Atua::TransportDocument.sum_or_zero(table[:freight_cents])]
      columns << Atua::TransportDocument.sum_or_zero(Atua::TransportDocument.net_freight) if @net

      columns
    end

    def grouped_documents
      return documents unless dimension == 'customer_group'

      documents.joins(customer_join)
    end

    def key_column
      case dimension
      when 'customer_group' then customers[:customer_group_id]
      when 'customer' then table[:taker_code]
      when 'vehicle' then plate
      when 'driver' then table[:driver_code]
      end
    end

    def label_column
      case dimension
      when 'customer_group' then customer_groups[:name].maximum
      when 'customer' then table[:taker_name].maximum
      when 'vehicle' then plate.maximum
      when 'driver' then table[:driver_name].maximum
      end
    end

    def customer_join
      table.join(customers, Arel::Nodes::OuterJoin)
        .on(customers[:tenant_id].eq(table[:tenant_id]).and(customers[:code].eq(table[:taker_code])))
        .join(customer_groups, Arel::Nodes::OuterJoin).on(customer_groups[:id].eq(customers[:customer_group_id]))
        .join_sources
    end

    def table
      Atua::TransportDocument.arel_table
    end

    def customers
      @customers ||= Atua::Customer.arel_table.alias('group_customers')
    end

    def customer_groups
      @customer_groups ||= CustomerGroup.arel_table.alias('group_customer_groups')
    end
  end
end
