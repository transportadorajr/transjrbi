module Dashboard
  class Goals
    FEATURE = :revenue_goals
    ON_TRACK_RATIO = 1
    ATTENTION_RATIO = BigDecimal('0.9')
    COMPANY_KEY = 'company'.freeze
    THIRD_PARTY_KEY = 'third_party'.freeze
    UNGROUPED_KEY = 'ungrouped'.freeze
    DEFAULT_SORT = 'realized'.freeze

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

    def initialize(documents, goals:, pace:, own_fleet: nil, week: nil, customer_groups: [])
      @documents = documents
      @goals = goals
      @pace = pace
      @own_fleet = own_fleet
      @week = week
      @customer_groups = customer_groups
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

    def customer_rows
      @customer_rows ||= customer_groups.map do |group|
        build_row(group.id.to_s, group.name, customer_group_goals[group.id], realized_by_customer_group.fetch(group.id, 0), cut: { customer_group_id: group.id },
                                                                                                                            **customer_group_week(group.id))
      end
    end

    def sorted_customer_rows
      customer_rows.sort_by { |row| [-row.realized_cents, row.label] }
    end

    def ungrouped_row
      realized = realized_by_customer_group.fetch(nil, 0)
      return if realized.zero?

      build_row(UNGROUPED_KEY, I18n.t('dashboards.goals.ungrouped'), nil, realized,
                week_realized_cents: (week_realized_by_customer_group.fetch(nil, 0) if week))
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

    attr_reader :documents, :goals, :own_fleet, :customer_groups

    def build_row(key, label, goal_cents, realized_cents, **)
      Row.new(key:, label:, goal_cents:, realized_cents:, projected_cents: pace.project(realized_cents), **)
    end

    def customer_group_goals
      @customer_group_goals ||= goals.select(&:customer_group?).to_h { |goal| [goal.customer_group_id, goal.amount_cents] }
    end

    def customer_group_week(customer_group_id)
      return {} unless week

      { week_goal_cents: week.goal_cents(:customer_group, customer_group_id:),
        week_realized_cents: week_realized_by_customer_group.fetch(customer_group_id, 0) }
    end

    def issued(period)
      documents.active.not_canceled.where(issued_at: period.first.beginning_of_day..period.last.end_of_day)
    end

    def by_customer_group(relation)
      relation.left_joins(:taker).group(Atua::Customer.arel_table[:customer_group_id]).sum(:freight_cents)
    end

    def realized_by_customer_group
      @realized_by_customer_group ||= by_customer_group(issued(pace.period))
    end

    def week_realized_by_plate
      @week_realized_by_plate ||= issued(week.period).group(:plate).sum(:freight_cents)
    end

    def week_realized_by_customer_group
      @week_realized_by_customer_group ||= by_customer_group(issued(week.period))
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
      @vehicle_goals ||= goals.select(&:vehicle?).to_h { |goal| [goal.plate, goal.amount_cents] }
    end

    def vehicle_plates
      (own_fleet&.plates.to_a | vehicle_goals.keys).sort
    end

    def realized_by_plate
      @realized_by_plate ||= issued(pace.period).group(:plate).sum(:freight_cents).transform_keys(&:to_s)
    end
  end
end
