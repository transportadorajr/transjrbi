module RevenueProjection
  Day = Data.define(:date, :realized_cents, :expected_cents, :low_cents, :high_cents, :holiday)
end
