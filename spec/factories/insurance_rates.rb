FactoryBot.define do
  factory :insurance_rate do
    tenant
    valid_from { Date.new(2026, 10, 1) }
    insurance_percentage { BigDecimal('0.022') }
    iof_percentage { BigDecimal('7.38') }
  end
end
