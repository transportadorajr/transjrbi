module Vacations
  class SeedCommand
    PATH = Rails.root.join('db/seeds/vacations.json')

    class << self
      def call(tenant, path: PATH)
        new(tenant, path).call
      end
    end

    def initialize(tenant, path)
      @tenant = tenant
      @path = path
    end

    def call
      data.fetch('vacations').each { |attributes| seed_vacation(attributes) }
    end

    private

    attr_reader :tenant, :path

    def data
      @data ||= JSON.parse(File.read(path))
    end

    def seed_vacation(attributes)
      employee = tenant.employees.find_by(attributes.slice('company_type', 'registration'))
      return if employee.nil?

      dates = Date.iso8601(attributes.fetch('start_on'))..Date.iso8601(attributes.fetch('end_on'))
      employee.update!(nickname: attributes['nickname']) if attributes['nickname'] && employee.nickname.blank?
      return if employee.vacations.overlapping(dates).exists?

      employee.vacations.create!(
        tenant:, start_on: dates.first, end_on: dates.last, acquisition_start_on: acquisition_start_on(employee, dates.first),
        sold_days: attributes.fetch('sold_days', 0), notes: attributes['notes']
      )
    end

    def acquisition_start_on(employee, start_on)
      VacationPeriod.start_dates(employee, start_on.prev_year).last || start_on.prev_year
    end
  end
end
