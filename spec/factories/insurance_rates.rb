FactoryBot.define do
  factory :insurance_rate do
    tenant
    insurance_percentage { BigDecimal('0.022') }
    iof_percentage { BigDecimal('7.38') }
  end
end
