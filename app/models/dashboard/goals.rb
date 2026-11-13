module Dashboard
  class Goals
    FEATURE = :revenue_goals
    ON_TRACK_RATIO = 1
    ATTENTION_RATIO = BigDecimal('0.9')
    COMPANY_KEY = 'company'.freeze
    THIRD_PARTY_KEY = 'third_party'.freeze
    DEFAULT_SORT = 'realized'.freeze

    Row = Data.define(:key, :label, :goal_cents, :realized_cents, :projected_cents) do
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

    def initialize(documents, goals:, pace:, own_fleet: nil)
      @documents = documents
      @goals = goals
      @pace = pace
      @own_fleet = own_fleet
    end

    attr_reader :pace

    delegate :month, to: :pace

    def company
      @company ||= build_row(COMPANY_KEY, I18n.t('dashboards.goals.company'), company_goal&.amount_cents, realized_by_plate.values.sum)
    end

    def vehicle_rows
      @vehicle_rows ||= vehicle_plates.map { |plate| build_row(plate, plate, vehicle_goals[plate], realized_by_plate.fetch(plate, 0)) }
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

    attr_reader :documents, :goals, :own_fleet

    def build_row(key, label, goal_cents, realized_cents)
      Row.new(key:, label:, goal_cents:, realized_cents:, projected_cents: pace.project(realized_cents))
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
      @realized_by_plate ||= documents.active.not_canceled.where(issued_at: pace.period.first.beginning_of_day..pace.period.last.end_of_day)
        .group(:plate).sum(:freight_cents).transform_keys(&:to_s)
    end
  end
end
