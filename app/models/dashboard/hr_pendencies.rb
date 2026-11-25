module Dashboard
  class HrPendencies
    RESOURCES = {
      uninsured: :life_insurances,
      missing_emergency_contact: :emergency_contacts,
      risk_assessment_expired: :risk_assessments,
      risk_assessment_expiring: :risk_assessments,
      vacation_overdue: :vacations,
      vacation_due_soon: :vacations,
      irregular_days_off: :work_schedules,
    }.freeze
    KINDS = RESOURCES.keys.freeze
    IRREGULAR_DAYS_OFF_ALERTS = (Dashboard::WorkSchedule::ALERTS - %i[next_week_missing]).freeze

    Row = Data.define(:employee, :pendencies)

    class << self
      def kinds_for(ability)
        KINDS.select { |kind| ability.can?(:read, RESOURCES.fetch(kind)) }
      end
    end

    attr_reader :kinds

    def initialize(tenant:, kinds: KINDS, today: Date.current)
      @tenant = tenant
      @kinds = kinds
      @today = today
    end

    def rows(employees)
      employees = employees.activated
      pendencies = pendencies_for(employees.reorder(nil))

      employees.to_a.filter_map do |employee|
        kinds_of_employee = kinds.select { |kind| pendencies[kind].include?(employee.id) }
        Row.new(employee:, pendencies: kinds_of_employee) if kinds_of_employee.any?
      end
    end

    def with_kind(rows, kind)
      return rows unless kinds.map(&:to_s).include?(kind.to_s)

      rows.select { |row| row.pendencies.include?(kind.to_sym) }
    end

    def counts(rows)
      kinds.index_with { |kind| rows.count { |row| row.pendencies.include?(kind) } }
    end

    private

    attr_reader :tenant, :today

    def pendencies_for(employees)
      kinds.index_with { |kind| Set.new(send(:"#{kind}_ids", employees)) }
    end

    def uninsured_ids(employees)
      employees.without_life_insurance(today).pluck(:id)
    end

    def missing_emergency_contact_ids(employees)
      employees.without_emergency_contact.pluck(:id)
    end

    def risk_assessment_expired_ids(employees)
      risk_assessments(employees).expired(today).pluck(:employee_id)
    end

    def risk_assessment_expiring_ids(employees)
      risk_assessments(employees).expiring(today).pluck(:employee_id)
    end

    def vacation_overdue_ids(employees)
      vacation_periods(employees).select { |period| period.status(today) == :overdue }.map { |period| period.employee.id }
    end

    def vacation_due_soon_ids(employees)
      vacation_periods(employees).select { |period| period.status(today) == :due_soon }.map { |period| period.employee.id }
    end

    def irregular_days_off_ids(employees)
      schedule = Dashboard::WorkSchedule.new(tenant:, week: today.iso8601)

      schedule.rows(schedule.employees.where(id: employees.select(:id)))
        .select { |row| row.alerts.intersect?(IRREGULAR_DAYS_OFF_ALERTS) }.map { |row| row.employee.id }
    end

    def risk_assessments(employees)
      tenant.risk_assessments.where(employee_id: employees.select(:id))
    end

    def vacation_periods(employees)
      @vacation_periods ||= Dashboard::VacationBalances.new(today:).periods(employees)
    end
  end
end
