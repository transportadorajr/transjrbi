module RevenueProjection
  Result = Data.define(:period_type, :period, :reference_at, :days, :factors, :history_days) do
    def realized_cents
      days.sum(&:realized_cents)
    end

    def projected_cents
      realized_cents + days.sum(&:expected_cents)
    end

    def low_cents
      realized_cents + days.sum(&:low_cents)
    end

    def high_cents
      realized_cents + days.sum(&:high_cents)
    end

    def realized
      Money.from_cents(realized_cents)
    end

    def projected
      Money.from_cents(projected_cents)
    end

    def low
      Money.from_cents(low_cents)
    end

    def high
      Money.from_cents(high_cents)
    end

    def upcoming_holidays
      days.select { it.date >= reference_at.to_date }.filter_map(&:holiday)
    end

    def history?
      history_days.positive?
    end
  end
end
