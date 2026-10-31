module Atua
  class ConvertValueCommand
    TIME_ZONE = 'America/Sao_Paulo'.freeze
    YES = %w[sim s].freeze
    NO = %w[nao n].freeze
    INTEGER = /\A-?\d+(\.0+)?\z/
    DECIMAL = /\A-?\d+(\.\d+)?\z/
    THOUSANDS = /\A-?\d{1,3}(\.\d{3})+\z/
    SHORT_DATE_TIME = %r{\A(\d{2})/(\d{2})/(\d{2}|\d{4}) (\d{2}):(\d{2})(?::(\d{2}))?\z}
    ISO_DATE_TIME = /\A(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2})(\.\d+)?)?\z/
    SHORT_DATE = %r{\A(\d{2})/(\d{2})/(\d{2}|\d{4})\z}
    ISO_DATE = /\A(\d{4})-(\d{2})-(\d{2})/
    TIME = /\A(\d{1,2}):(\d{2})(?::(\d{2}))?\z/
    NUMBER_SEPARATOR = %r{\s*/\s*}
    TYPES = %i[
      string integer cents decimal list date datetime yes_no document plate number_series state_city code_name month_date
    ].freeze

    class << self
      def call(tenant, value, type, **)
        new(tenant, value, type, **).call
      end
    end

    def initialize(tenant, value, type, **options)
      @tenant = tenant
      @value = value
      @type = type
      @options = options
    end

    def call
      raise ArgumentError, I18n.t('atua.errors.unknown_conversion', type:) unless TYPES.include?(type)

      send(:"to_#{type}")
    end

    private

    attr_reader :tenant, :value, :type, :options

    def to_string(raw = value)
      text = case raw
             when nil then nil
             when Float then raw == raw.truncate ? raw.to_i.to_s : BigDecimal(raw.to_s).to_s('F')
             when Date then raw.to_date.iso8601
             else raw.to_s.strip
             end
      text = text.rjust(options[:pad], '0') if options[:pad] && raw.is_a?(Numeric) && text.match?(/\A\d+\z/)

      text.presence
    end

    def to_integer(raw = value)
      case raw
      when nil then nil
      when Integer then raw
      when Float then raw == raw.truncate ? raw.to_i : invalid!
      else
        text = raw.to_s.strip
        return if text.empty?

        text.match?(INTEGER) ? text.to_i : invalid!
      end
    end

    def to_cents
      amount = to_decimal
      amount && (amount * 100).round
    end

    def to_decimal
      case value
      when nil then nil
      when Integer then BigDecimal(value)
      when Float then BigDecimal(value.to_s)
      else parse_number(value.to_s)
      end
    end

    def to_list
      text = to_string
      return [] if text.nil?

      item_type = options.fetch(:of, :string)
      text.split(options.fetch(:separator, ',')).filter_map do |item|
        self.class.call(tenant, item, item_type)
      end
    end

    def to_date
      case value
      when nil then nil
      when Date, Time then value.to_date
      else
        text = value.to_s.strip
        return if text.empty?

        parse_date(text)
      end
    end

    def to_datetime
      return combine_date_and_time if options.key?(:time)

      case value
      when nil then nil
      when Time then value.in_time_zone(time_zone)
      when DateTime, Date then time_zone.local(value.year, value.month, value.day)
      else
        text = value.to_s.strip
        return if text.empty?

        parse_date_time(text)
      end
    end

    def to_yes_no
      text = to_string
      return if text.nil?

      answer = I18n.transliterate(text).downcase
      return if NO.include?(answer)
      return invalid! unless YES.include?(answer)

      atua_time || options[:previous] || options[:now] || Time.current
    end

    def to_document
      to_string&.gsub(/\D/, '').presence
    end

    def to_plate
      to_string&.upcase&.gsub(/[\s-]/, '').presence
    end

    def to_number_series
      text = to_string
      return [nil, nil] if text.nil?

      number, series = text.split(NUMBER_SEPARATOR, 2)
      invalid! if series.nil?

      [to_integer(number), to_integer(series)]
    end

    def to_state_city
      text = to_string
      return [nil, nil] if text.nil?

      state, city = text.split(NUMBER_SEPARATOR, 2)
      invalid! if city.nil?

      [state, city]
    end

    def to_code_name
      text = to_string
      return [nil, nil] if text.nil?

      code, name = text.split(NUMBER_SEPARATOR, 2)
      invalid! if name.nil?

      [to_integer(code), name.strip.presence]
    end

    def to_month_date
      month = to_integer
      year = to_integer(options[:year])
      return if month.nil? || year.nil?

      Date.new(year, month, 1)
    rescue Date::Error
      invalid!
    end

    def atua_time
      date = options[:date]
      return if date.blank?
      return date.in_time_zone(time_zone) if date.is_a?(Time)

      self.class.call(tenant, date, :datetime)
    end

    def combine_date_and_time
      date = to_date
      return if date.nil?

      time = to_string(options[:time])
      return time_zone.local(date.year, date.month, date.day) if time.nil?

      match = TIME.match(time) || invalid!(time)
      time_zone.local(date.year, date.month, date.day, match[1].to_i, match[2].to_i, match[3].to_i)
    end

    def parse_number(text)
      text = text.strip.delete_prefix('R$').strip
      return if text.empty?

      if text.include?(',')
        text = text.delete('.').tr(',', '.')
      elsif text.match?(THOUSANDS)
        text = text.delete('.')
      end

      text.match?(DECIMAL) ? BigDecimal(text) : invalid!
    end

    def parse_date(text)
      if (match = SHORT_DATE.match(text))
        year = match[3].to_i
        year += 2000 if match[3].size == 2
        Date.new(year, match[2].to_i, match[1].to_i)
      elsif (match = ISO_DATE.match(text))
        Date.new(match[1].to_i, match[2].to_i, match[3].to_i)
      else
        invalid!
      end
    rescue Date::Error
      invalid!
    end

    def parse_date_time(text)
      if (match = SHORT_DATE_TIME.match(text))
        year = match[3].to_i
        year += 2000 if match[3].size == 2
        time_zone.local(year, match[2].to_i, match[1].to_i, match[4].to_i, match[5].to_i, match[6].to_i)
      elsif (match = ISO_DATE_TIME.match(text))
        microseconds = (BigDecimal("0#{match[7] || '.0'}") * 1_000_000).to_i
        time_zone.local(*match.captures.first(6).map(&:to_i), microseconds)
      else
        invalid!
      end
    rescue ArgumentError
      invalid!
    end

    def time_zone
      ActiveSupport::TimeZone[TIME_ZONE]
    end

    def invalid!(raw = value)
      raise ConversionError, I18n.t('atua.errors.invalid_value', value: raw.inspect, type:)
    end
  end
end
