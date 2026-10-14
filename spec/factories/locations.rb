FactoryBot.define do
  factory :location do
    sequence(:lookup_key) { |n| "|CIDADE #{n}|MG" }
    city { 'Ipatinga' }
    state { 'MG' }
    sequence(:latitude) { |n| BigDecimal('-19.4') - (n * BigDecimal('0.01')) }
    longitude { BigDecimal('-42.5') }
    precision_type { 'city' }
  end
end
