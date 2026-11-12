module RevenueProjection
  class FactorSet
    def initialize(factors)
      @values = factors.to_h { |factor| [[factor.factor_type.to_sym, factor.wday], factor.value.to_f] }
    end

    def value(factor_type, wday = nil)
      values.fetch([factor_type.to_sym, wday]) { Factor::DEFAULTS.fetch(factor_type.to_sym) }
    end

    def bias(wday)
      value(:weekday_bias, wday)
    end

    def day_factor(day_type, wday)
      day_type.to_sym == :regular ? bias(wday) : value(day_type) * bias(wday)
    end

    def to_h
      Factor::DEFAULTS.keys.excluding(:weekday_bias).index_with { value(it) }
    end

    private

    attr_reader :values
  end
end
