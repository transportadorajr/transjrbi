class TripDuration
  include Comparable

  MIN_MEASURED = 1.hour
  MAX_MEASURED = 15.days
  SECONDS_PER_HOUR = 3600

  attr_reader :seconds

  class << self
    def between(started_at, finished_at)
      return if started_at.nil? || finished_at.nil? || finished_at <= started_at

      new(finished_at - started_at)
    end

    def from_seconds(seconds)
      new(seconds) if seconds.to_d.positive?
    end
  end

  def initialize(seconds)
    @seconds = seconds.to_d
  end

  def <=>(other)
    seconds <=> other.seconds
  end

  def hours
    (seconds / SECONDS_PER_HOUR).round
  end

  def days
    hours / 24
  end

  def remaining_hours
    hours % 24
  end

  def measured?
    seconds.between?(MIN_MEASURED, MAX_MEASURED)
  end

  def net_per_hour(net)
    Money.from_cents((net.cents.to_d * SECONDS_PER_HOUR / seconds).round(0, BigDecimal::ROUND_HALF_UP))
  end
end
