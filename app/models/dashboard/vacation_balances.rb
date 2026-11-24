module Dashboard
  class VacationBalances
    STATUSES = %i[overdue due_soon open].freeze

    def initialize(today: Date.current)
      @today = today
    end

    def periods(employees)
      periods = employees.activated.where.not(admitted_on: nil).preload(:vacations).flat_map do |employee|
        VacationPeriod.for_employee(employee, vacations: employee.vacations.to_a, until_on: today)
          .select { |period| STATUSES.include?(period.status(today)) }
      end

      periods.sort_by { |period| [period.deadline_on, period.employee.name] }
    end

    def with_status(periods, status)
      return periods unless STATUSES.map(&:to_s).include?(status.to_s)

      periods.select { |period| period.status(today) == status.to_sym }
    end

    def counts(periods)
      STATUSES.index_with { |status| periods.count { |period| period.status(today) == status } }
    end

    private

    attr_reader :today
  end
end
