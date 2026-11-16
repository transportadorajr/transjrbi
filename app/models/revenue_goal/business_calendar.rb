class RevenueGoal
  class BusinessCalendar
    def initialize(holidays)
      @holidays = holidays
    end

    def business_day?(date)
      return false if date.sunday?

      holiday = holidays[date]
      holiday.nil? || holiday.optional?
    end

    def business_days(period)
      period.select { |date| business_day?(date) }
    end

    private

    attr_reader :holidays
  end
end
