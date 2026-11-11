module Holidays
  class SeedNationalCommand
    FIXED_DATES = {
      new_year: [1, 1],
      tiradentes: [4, 21],
      labour_day: [5, 1],
      independence_day: [9, 7],
      our_lady_aparecida: [10, 12],
      all_souls_day: [11, 2],
      republic_day: [11, 15],
      black_consciousness_day: [11, 20],
      christmas: [12, 25],
    }.freeze
    EASTER_OFFSETS = {
      carnival_monday: [-48, :optional],
      carnival_tuesday: [-47, :optional],
      good_friday: [-2, :holiday],
      corpus_christi: [60, :optional],
    }.freeze
    FIRST_YEARS = { black_consciousness_day: 2024 }.freeze
    BRIDGE_OFFSETS = { 2 => -1, 4 => 1 }.freeze

    class << self
      def call(tenant, years: default_years)
        new(tenant, years).call
      end

      def default_years
        (Date.current.year - 1)..(Date.current.year + 1)
      end

      def easter(year)
        a = year % 19
        b, c = year.divmod(100)
        d, e = b.divmod(4)
        g = (b - ((b + 8) / 25) + 1) / 3
        h = ((19 * a) + b - d - g + 15) % 30
        l = (32 + (2 * e) + (2 * (c / 4)) - h - (c % 4)) % 7
        month, day = (h + l - (7 * ((a + (11 * h) + (22 * l)) / 451)) + 114).divmod(31)

        Date.new(year, month, day + 1)
      end
    end

    def initialize(tenant, years)
      @tenant = tenant
      @years = Array(years)
    end

    def call
      years.each { |year| seed(year) unless seeded?(year) }

      tenant.holidays.national.where(date: Date.new(years.min).beginning_of_year..Date.new(years.max).end_of_year).order(:date)
    end

    private

    attr_reader :tenant, :years

    def seeded?(year)
      tenant.holidays.national.by_year(year).exists?
    end

    def seed(year)
      holidays = (fixed_holidays(year) + easter_holidays(year)).sort_by { it[:date] }
      taken = holidays.to_set { it[:date] }

      Holiday.transaction do
        holidays.each { |attributes| create(**attributes) }
        bridges(holidays, taken).each { |attributes| create(**attributes) }
      end
    end

    def fixed_holidays(year)
      FIXED_DATES.filter_map do |key, (month, day)|
        next if year < FIRST_YEARS.fetch(key, year)

        { date: Date.new(year, month, day), name: holiday_name(key), kind_type: :holiday }
      end
    end

    def easter_holidays(year)
      easter = self.class.easter(year)

      EASTER_OFFSETS.map do |key, (offset, kind_type)|
        { date: easter + offset, name: holiday_name(key), kind_type: }
      end
    end

    def bridges(holidays, taken)
      holidays.filter_map do |holiday|
        offset = BRIDGE_OFFSETS[holiday[:date].wday]
        next unless offset && holiday[:kind_type] == :holiday

        date = holiday[:date] + offset
        next unless taken.add?(date)

        { date:, name: I18n.t('holidays.national.bridge_day', name: holiday[:name]), kind_type: :bridge_day }
      end
    end

    def create(date:, name:, kind_type:)
      tenant.holidays.find_or_create_by!(date:) do |holiday|
        holiday.assign_attributes(name:, kind_type:, scope_type: :national)
      end
    end

    def holiday_name(key)
      I18n.t(key, scope: 'holidays.national')
    end
  end
end
