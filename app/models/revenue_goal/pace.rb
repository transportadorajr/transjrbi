class RevenueGoal
  class Pace
    def initialize(month, reference_date:, holidays:, projection: nil)
      @month = month.beginning_of_month
      @reference_date = reference_date
      @calendar = BusinessCalendar.new(holidays)
      @projection = projection
    end

    attr_reader :month, :reference_date

    def period
      month.all_month
    end

    def closed?
      reference_date > period.last
    end

    def started?
      reference_date >= period.first
    end

    def learned?
      !closed? && projection.present? && projection.history? && projection.realized_cents.positive?
    end

    def business_days
      @business_days ||= calendar.business_days(period)
    end

    def elapsed_business_days
      business_days.count { |date| date <= reference_date }
    end

    def remaining_business_days
      business_days.count { |date| date > reference_date }
    end

    def project(realized_cents)
      return realized_cents if closed?
      return unless started?
      return (realized_cents * projection.projected_cents.to_d / projection.realized_cents).round if learned?

      (realized_cents * business_days.size.to_d / elapsed_business_days).round if elapsed_business_days.positive?
    end

    private

    attr_reader :calendar, :projection
  end
end
