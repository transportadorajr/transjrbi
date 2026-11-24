module Dashboard
  class WorkSchedule
    DAYS_OFF_PER_WEEK = 2
    WEEK_START = :sunday
    WEEK_LENGTH = 7
    ALERTS = %i[few_days_off sunday_overdue].freeze
    ANY_ALERT = 'any'.freeze

    Day = Data.define(:date, :status, :city, :leave_reason_type, :entry) do
      def day_off?
        status == :day_off
      end
    end

    Sunday = Data.define(:status, :last_on, :due_on)

    Row = Data.define(:employee, :days, :sunday, :alerts) do
      def days_off_count
        days.count(&:day_off?)
      end

      def owed_days_off
        [DAYS_OFF_PER_WEEK - days_off_count, 0].max
      end
    end

    attr_reader :week_start

    def initialize(tenant:, week: nil)
      @tenant = tenant
      @week_start = parse_week(week).beginning_of_week(WEEK_START)
    end

    def dates
      week_start..(week_start + (WEEK_LENGTH - 1))
    end

    def entry_date
      dates.cover?(Date.current) ? Date.current : week_start
    end

    def previous_week
      week_start - WEEK_LENGTH
    end

    def next_week
      week_start + WEEK_LENGTH
    end

    def employees
      tenant.employees.scheduled_in(dates).preload(:driver)
    end

    def with_alert(rows, kind)
      case kind.to_s
      when ANY_ALERT then rows.select { |row| row.alerts.any? }
      when *ALERTS.map(&:to_s) then rows.select { |row| row.alerts.include?(kind.to_sym) }
      else rows
      end
    end

    def alert_counts(rows)
      ALERTS.index_with { |kind| rows.count { |row| row.alerts.include?(kind) } }.merge(any: rows.count { |row| row.alerts.any? })
    end

    def rows(employees)
      employees = employees.to_a
      entries = entries_for(employees)
      trips = trip_dates_for(employees)
      last_sundays = last_sundays_off_for(employees)

      employees.map do |employee|
        days = dates.map { |date| day_for(entries[[employee.id, date]], trips[employee.driver_code], date) }

        sunday = sunday_for(employee, last_sundays[employee.id], days.first)

        Row.new(employee:, days:, sunday:, alerts: alerts_for(days, sunday))
      end
    end

    private

    attr_reader :tenant

    def parse_week(week)
      Date.iso8601(week.to_s)
    rescue Date::Error
      Date.current
    end

    def day_for(entry, trip_dates, date)
      if entry
        Day.new(date:, status: entry.kind_type.to_sym, city: entry.city, leave_reason_type: entry.leave_reason_type, entry:)
      else
        Day.new(date:, status: trip_dates&.include?(date) ? :trip : :work, city: nil, leave_reason_type: nil, entry: nil)
      end
    end

    def alerts_for(days, sunday)
      ALERTS.select do |kind|
        case kind
        when :few_days_off then few_days_off?(days)
        when :sunday_overdue then sunday.status == :overdue
        end
      end
    end

    def few_days_off?(days)
      owed = [DAYS_OFF_PER_WEEK - days.count(&:day_off?), 0].max
      today = Date.current
      return false if owed.zero? || week_start > today

      days.count { |day| day.date >= today && day.status == :work } < owed
    end

    def sunday_for(employee, last_on, week_sunday)
      return Sunday.new(status: :unknown, last_on: nil, due_on: nil) if last_on.nil?

      due_on = (last_on + employee.sunday_off_interval).beginning_of_week(WEEK_START)

      Sunday.new(status: sunday_status(last_on, due_on, week_sunday), last_on:, due_on:)
    end

    def sunday_status(last_on, due_on, week_sunday)
      if last_on == week_sunday.date then :taken
      elsif due_on < week_sunday.date then :overdue
      elsif due_on == week_sunday.date then week_sunday.status == :trip ? :overdue : :due
      else :on_track
      end
    end

    def last_sundays_off_for(employees)
      tenant.work_schedule_days.day_off.on_sundays.where(employee_id: employees.map(&:id)).where(date: ..week_start)
        .group(:employee_id).maximum(:date)
    end

    def entries_for(employees)
      tenant.work_schedule_days.where(employee_id: employees.map(&:id)).by_period(dates).preload(:city)
        .index_by { |entry| [entry.employee_id, entry.date] }
    end

    def trip_dates_for(employees)
      WorkSchedules::TripDatesCommand.call(tenant, employees.filter_map(&:driver_code), dates)
    end
  end
end
