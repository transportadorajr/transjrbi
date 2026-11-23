module Employees
  class LinkDriverCommand
    class << self
      def call(employee)
        new(employee).call
      end
    end

    def initialize(employee)
      @employee = employee
    end

    def call
      driver = matching_driver
      employee.update!(driver:) unless employee.driver_id == driver&.id

      employee.driver
    end

    private

    attr_reader :employee

    def matching_driver
      code = driver_code
      return if code.nil?

      driver = tenant.drivers.find_or_create_by!(code:)
      driver unless tenant.employees.where.not(id: employee.id).exists?(driver:)
    end

    def driver_code
      tenant.atua_transport_documents
        .where(driver_document_digits: employee.legal_id)
        .where.not(driver_code: nil)
        .order(issued_at: :desc, id: :desc)
        .pick(:driver_code)
    end

    def tenant
      employee.tenant
    end
  end
end
