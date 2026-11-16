module Dashboard
  class Goals
    FEATURE = :revenue_goals
    ON_TRACK_RATIO = 1
    ATTENTION_RATIO = BigDecimal('0.9')
    COMPANY_KEY = 'company'.freeze
    THIRD_PARTY_KEY = 'third_party'.freeze
    DEFAULT_SORT = 'realized'.freeze
    DIMENSIONS = { 'customer_group' => :customer_groups, 'vehicle' => :vehicles, 'driver' => :drivers, 'macro_region' => :regions }.freeze
    DEFAULT_DIMENSION = 'customer_group'.freeze
    BREAKDOWNS = {
      customer_groups: { list_all: true, cut: :customer_group_id, extra_label: 'dashboards.goals.ungrouped' },
      drivers: { list_all: false, cut: :driver_code },
      regions: { list_all: false, cut: :macro_region_id, extra_label: 'dashboards.goals.no_region', extra_cut: MacroRegion::OTHERS },
    }.freeze

    Row = Data.define(:key, :label, :goal_cents, :realized_cents, :projected_cents, :cut, :week_goal_cents, :week_realized_cents) do
      extend ActiveModel::Naming

      def initialize(cut: nil, week_goal_cents: nil, week_realized_cents: nil, **)
        super
      end

      def confirmation_name
        label
      end

      def week_goal?
        !week_goal_cents.nil?
      end

      def week_missing_cents
        [week_goal_cents - week_realized_cents.to_i, 0].max if week_goal?
      end

      def week_ratio
        week_realized_cents.to_i.to_d / week_goal_cents if week_goal? && week_goal_cents.positive?
      end

      def goal?
        !goal_cents.nil?
      end

      def missing_cents
        [goal_cents - realized_cents, 0].max if goal?
      end

      def ratio
        realized_cents.to_d / goal_cents if goal?
      end

      def projected_ratio
        projected_cents.to_d / goal_cents if goal? && projected_cents
      end

      def status
        return unless projected_ratio
        return :on_track if projected_ratio >= ON_TRACK_RATIO

        projected_ratio >= ATTENTION_RATIO ? :attention : :behind
      end
    end

    SORT_VALUES = {
      'label' => ->(row) { row.label },
      'realized' => ->(row) { row.realized_cents },
      'ratio' => ->(row) { row.ratio || -1 },
    }.freeze

    class << self
      def enabled?(tenant)
        Flipper.enabled?(FEATURE, tenant)
      end
    end

    def initialize(documents, targets:, pace:, own_fleet: nil, week: nil)
      @documents = documents
      @targets = targets
      @pace = pace
      @own_fleet = own_fleet
      @week = week
    end

    attr_reader :pace, :week

    delegate :month, to: :pace

    def company
      @company ||= build_row(COMPANY_KEY, I18n.t('dashboards.goals.company'), company_goal&.amount_cents, realized_by_plate.values.sum,
                             week_goal_cents: week&.goal_cents(:company), week_realized_cents: (week_realized_by_plate.values.sum if week))
    end

    def week?
      !week.nil?
    end

    def vehicle_rows
      @vehicle_rows ||= vehicle_plates.map do |plate|
        build_row(plate, plate, vehicle_goals[plate], realized_by_plate.fetch(plate, 0), cut: { plate: })
      end
    end

    def breakdown_rows(section)
      @breakdown_rows ||= {}
      @breakdown_rows[section] ||= breakdown_keys(section).map { |key| breakdown_row(section, key) }.sort_by { |row| [-row.realized_cents, row.label] }
    end

    def breakdown_extra_row(section)
      config = BREAKDOWNS.fetch(section)
      realized = breakdown_realized(section).fetch('', 0)
      return if config[:extra_label].nil? || realized.zero?

      build_row("#{section}_none", I18n.t(config[:extra_label]), nil, realized, cut: ({ config[:cut] => config[:extra_cut] } if config[:extra_cut]),
                                                                                week_realized_cents: (breakdown_week_realized(section).fetch('', 0) if week))
    end

    def chart_data
      expected = expected_by_day
      series = [{ name: I18n.t('dashboards.goals.realized_accumulated'), data: realized_by_day }]
      series << { name: I18n.t('dashboards.goals.expected_accumulated'), data: expected } if expected
      series
    end

    def sorted_vehicle_rows(column, direction)
      column = SORT_VALUES.key?(column.to_s) ? column.to_s : DEFAULT_SORT
      sorted = vehicle_rows.sort_by { |row| [SORT_VALUES.fetch(column).call(row), row.key] }
      direction = column == DEFAULT_SORT && direction.blank? ? 'desc' : direction.to_s

      direction == 'desc' ? sorted.reverse : sorted
    end

    def third_party_row
      return unless own_fleet&.plates&.any?

      realized = realized_by_plate.select { |plate, _| own_fleet.third_party?(plate) }.values.sum
      build_row(THIRD_PARTY_KEY, I18n.t('own_fleets.third_party'), nil, realized)
    end

    def vehicle_goals_cents
      vehicle_goals.values.sum
    end

    def required_daily_cents
      return unless company.goal? && !pace.closed?
      return company.missing_cents if pace.remaining_business_days.zero?

      (company.missing_cents.to_d / pace.remaining_business_days).ceil
    end

    private

    attr_reader :documents, :targets, :own_fleet

    delegate :goals, to: :targets

    def build_row(key, label, goal_cents, realized_cents, **)
      Row.new(key:, label:, goal_cents:, realized_cents:, projected_cents: pace.project(realized_cents), **)
    end

    def breakdown_keys(section)
      options = targets.options(section)
      return options.keys if BREAKDOWNS.fetch(section)[:list_all]

      options.keys.select { |key| targets.goal_amounts(section).key?(key) || breakdown_realized(section).fetch(key, 0).positive? }
    end

    def breakdown_row(section, key)
      cut = BREAKDOWNS.fetch(section)[:cut]
      build_row(key, targets.options(section).fetch(key), targets.goal_amounts(section)[key], breakdown_realized(section).fetch(key, 0),
                cut: ({ cut => key.to_i } if cut), **breakdown_week(section, key))
    end

    def breakdown_week(section, key)
      return {} unless week

      { week_goal_cents: week.goal_cents(RevenueGoal::Targets::SECTIONS.fetch(section), key),
        week_realized_cents: breakdown_week_realized(section).fetch(key, 0) }
    end

    def breakdown_realized(section)
      @breakdown_realized ||= {}
      @breakdown_realized[section] ||= targets.billing(section, issued(pace.period))
    end

    def breakdown_week_realized(section)
      @breakdown_week_realized ||= {}
      @breakdown_week_realized[section] ||= targets.billing(section, issued(week.period))
    end

    def issued(period)
      documents.active.not_canceled.where(issued_at: period.first.beginning_of_day..period.last.end_of_day)
    end

    def week_realized_by_plate
      @week_realized_by_plate ||= issued(week.period).group(:plate).sum(:freight_cents)
    end

    def chart_days
      pace.period.select { |date| date <= pace.reference_date }
    end

    def realized_by_day
      daily = issued(pace.period).group_by_day(:issued_at, range: pace.period).sum(:freight_cents)
      total = 0

      chart_days.to_h { |date| [I18n.l(date, format: :chart_week), Money.from_cents(total += daily.fetch(date, 0)).to_f] }
    end

    def expected_by_day
      return unless company.goal? && pace.business_days.any?

      elapsed = 0
      pace.period.to_h do |date|
        elapsed += 1 if pace.business_days.include?(date)
        [I18n.l(date, format: :chart_week), Money.from_cents((company.goal_cents.to_d * elapsed / pace.business_days.size).round).to_f]
      end
    end

    def company_goal
      goals.find(&:company?)
    end

    def vehicle_goals
      @vehicle_goals ||= targets.goal_amounts(:vehicles)
    end

    def vehicle_plates
      (own_fleet&.plates.to_a | vehicle_goals.keys).sort
    end

    def realized_by_plate
      @realized_by_plate ||= issued(pace.period).group(:plate).sum(:freight_cents).transform_keys(&:to_s)
    end
  end
end
