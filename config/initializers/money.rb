MoneyRails.configure do |config|
  config.default_currency = :brl
  config.locale_backend = :i18n
  config.rounding_mode = BigDecimal::ROUND_HALF_EVEN
end
