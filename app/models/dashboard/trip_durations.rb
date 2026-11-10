module Dashboard
  class TripDurations
    Fact = Data.define(:duration, :net_cents, :in_progress) do
      def measured?
        !duration.nil? && duration.measured?
      end
    end

    class << self
      def build_fact(seconds, net_cents, in_progress)
        Fact.new(duration: TripDuration.from_seconds(seconds.to_d), net_cents: net_cents.to_i, in_progress: in_progress == true)
      end
    end

    def initialize(facts)
      @facts = facts
    end

    def measured_count
      measured.size
    end

    def in_progress_count
      facts.count(&:in_progress)
    end

    def excluded_count
      facts.count { |fact| fact.duration && !fact.measured? }
    end

    def average
      TripDuration.from_seconds(total_seconds / measured.size) if measured.any?
    end

    def net_per_hour
      TripDuration.from_seconds(total_seconds)&.net_per_hour(Money.from_cents(measured.sum(&:net_cents)))
    end

    private

    attr_reader :facts

    def measured
      @measured ||= facts.select(&:measured?)
    end

    def total_seconds
      measured.sum(BigDecimal('0')) { |fact| fact.duration.seconds }
    end
  end
end
