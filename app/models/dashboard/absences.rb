module Dashboard
  class Absences
    UPCOMING_MONTHS = 3

    Absence = Data.define(:employee, :kind, :start_on, :end_on, :leave_reason_type) do
      def dates
        start_on..end_on
      end

      def vacation?
        kind == :vacation
      end

      def days_count
        (end_on - start_on).to_i + 1
      end
    end

    Day = Data.define(:date, :absences) do
      delegate :any?, to: :absences
    end

    attr_reader :month

    def initialize(tenant:, month: nil)
      @tenant = tenant
      @month = Vacation.month_dates(month || Date.current.strftime('%Y-%m')).first
    end

    def dates
      month.all_month
    end

    def previous_month
      month.prev_month
    end

    delegate :next_month, to: :month

    def upcoming_dates
      next_month..month.advance(months: UPCOMING_MONTHS).end_of_month
    end

    def absences
      @absences ||= absences_in(dates)
    end

    def upcoming_absences
      @upcoming_absences ||= absences_in(dates.first..upcoming_dates.last).select { |absence| upcoming_dates.cover?(absence.start_on) }
    end

    def days
      @days ||= dates.map { |date| Day.new(date:, absences: absences.select { |absence| absence.dates.cover?(date) }) }
    end

    def weeks
      padding = Array.new(dates.first.wday)
      (padding + days).each_slice(7).map { |week| week + Array.new(7 - week.size) }
    end

    def employees_count(kind = nil)
      absences.select { |absence| kind.nil? || absence.kind == kind }.map { |absence| absence.employee.id }.uniq.size
    end

    def days_in_month(absence)
      ([absence.end_on, dates.last].min - [absence.start_on, dates.first].max).to_i + 1
    end

    private

    attr_reader :tenant

    def absences_in(dates)
      (vacation_absences(dates) + leave_absences(dates)).sort_by { |absence| [absence.start_on, absence.employee.name, absence.kind] }
    end

    def vacation_absences(dates)
      tenant.vacations.overlapping(dates).preload(:employee).map do |vacation|
        Absence.new(employee: vacation.employee, kind: :vacation, start_on: vacation.start_on, end_on: vacation.end_on, leave_reason_type: nil)
      end
    end

    def leave_absences(dates)
      leaves = tenant.work_schedule_days.leave.by_period(dates).preload(:employee).order(:employee_id, :date).to_a

      leaves.slice_when { |previous, current| !same_leave?(previous, current) }.map do |block|
        Absence.new(employee: block.first.employee, kind: :leave, start_on: block.first.date, end_on: block.last.date,
                    leave_reason_type: block.first.leave_reason_type)
      end
    end

    def same_leave?(previous, current)
      previous.employee_id == current.employee_id && previous.date + 1 == current.date &&
        previous.leave_reason_type == current.leave_reason_type
    end
  end
end
