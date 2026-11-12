module RevenueProjection
  class Calendar
    MONTH_END_DAYS = 3

    def initialize(holidays)
      @holidays = holidays
    end

    def day_type(date)
      holiday = holidays[date]
      return holiday_day_type(holiday) if holiday && !date.sunday?

      month_end?(date) ? :month_end : :regular
    end

    def month_end?(date)
      !date.sunday? && month_end_dates(date.year, date.month).include?(date)
    end

    private

    attr_reader :holidays

    def holiday_day_type(holiday)
      return :bridge_day if holiday.bridge_day?
      return :optional_day if holiday.optional?

      holiday.date.saturday? ? :saturday_holiday : :weekday_holiday
    end

    def month_end_dates(year, month)
      @month_end_dates ||= {}
      @month_end_dates[[year, month]] ||= Date.new(year, month, -1).downto(Date.new(year, month, 1)).reject(&:sunday?).first(MONTH_END_DAYS)
    end
  end
end
