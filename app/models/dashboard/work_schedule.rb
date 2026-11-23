module Dashboard
  class WorkSchedule
    DAYS_OFF_PER_WEEK = 2
    WEEK_START = :sunday
    WEEK_LENGTH = 7

    Day = Data.define(:date, :status, :city, :leave_reason_type) do
      def day_off?
        status == :day_off
      end
    end

    Row = Data.define(:employee, :days) do
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

    def previous_week
      week_start - WEEK_LENGTH
    end

    def next_week
      week_start + WEEK_LENGTH
    end

    def employees
      tenant.employees.scheduled_in(dates).preload(:driver)
    end

    def rows(employees)
      employees = employees.to_a
      entries = entries_for(employees)
      trips = trip_dates_for(employees)

      employees.map do |employee|
        Row.new(employee:, days: dates.map { |date| day_for(entries[[employee.id, date]], trips[employee.driver_code], date) })
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
        Day.new(date:, status: entry.kind_type.to_sym, city: entry.city, leave_reason_type: entry.leave_reason_type)
      else
        Day.new(date:, status: trip_dates&.include?(date) ? :trip : :work, city: nil, leave_reason_type: nil)
      end
    end

    def entries_for(employees)
      tenant.work_schedule_days.where(employee_id: employees.map(&:id)).by_period(dates).preload(:city)
        .index_by { |entry| [entry.employee_id, entry.date] }
    end

    def trip_dates_for(employees)
      codes = employees.filter_map(&:driver_code)
      return {} if codes.empty?

      trips(codes).each_with_object(Hash.new { |hash, code| hash[code] = Set.new }) do |(code, started_at, departure_on, issued_on, closed_at), result|
        start = started_at&.to_date || departure_on || issued_on
        next if start.nil?

        finish = closed_at&.to_date || (started_at ? Date.current : start)
        result[code].merge(dates.grep(start..finish))
      end
    end

    def trips(codes)
      manifests = Atua::Manifest.arel_table
      documents = Atua::TransportDocument.arel_table

      Atua::ManifestDocument.active.where(tenant:).joins(:manifest, :transport_document)
        .merge(Atua::Manifest.trips)
        .merge(Atua::TransportDocument.active.not_canceled.where(driver_code: codes))
        .where(manifests[:closed_at].eq(nil).or(manifests[:closed_at].gteq(week_start.beginning_of_day)))
        .distinct
        .pluck(documents[:driver_code], manifests[:trip_started_at], manifests[:departure_on], manifests[:issued_on], manifests[:closed_at])
    end
  end
end
