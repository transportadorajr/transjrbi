module Employees
  class SeedAdmissionsCommand
    PATH = Rails.root.join('db/seeds/admissions.json')

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
      data.fetch('admissions').each { |attributes| seed_admission(attributes) }
    end

    private

    attr_reader :tenant, :path

    def data
      @data ||= JSON.parse(File.read(path))
    end

    def seed_admission(attributes)
      employee = tenant.employees.find_by(attributes.slice('company_type', 'registration'))
      return if employee.nil? || employee.admitted_on.present?

      Employee.transaction do
        employee.update!(admitted_on: Date.iso8601(attributes.fetch('admitted_on')))
        realign_vacations(employee)
      end
    end

    def realign_vacations(employee)
      employee.vacations.each do |vacation|
        acquisition_start_on = VacationPeriod.start_dates(employee, vacation.start_on.prev_year).last
        next if acquisition_start_on.nil? || acquisition_start_on == vacation.acquisition_start_on

        vacation.update!(acquisition_start_on:)
      end
    end
  end
end
