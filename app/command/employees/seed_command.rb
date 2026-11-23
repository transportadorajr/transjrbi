module Employees
  class SeedCommand
    PATH = Rails.root.join('db/seeds/employees.json')
    TRUNCATED_NAME_LENGTH = 30
    CPF_LENGTH = 11

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
      job_positions = data.fetch('job_positions').index_with { |name| tenant.job_positions.find_or_create_by!(name:) }

      data.fetch('employees').each { |attributes| seed_employee(attributes, job_positions) }
    end

    private

    attr_reader :tenant, :path

    def data
      @data ||= JSON.parse(File.read(path))
    end

    def seed_employee(attributes, job_positions)
      return if tenant.employees.exists?(attributes.slice('company_type', 'registration'))

      name, legal_id = driver_identity(attributes.fetch('name'))
      return if legal_id && tenant.employees.exists?(legal_id:)

      employee = tenant.employees.create!(
        **attributes.slice('company_type', 'registration', 'cost_center', 'gender_type').symbolize_keys,
        name:, legal_id:, job_position: job_positions.fetch(attributes.fetch('job_position'))
      )
      LinkDriverCommand.call(employee)
    end

    def driver_identity(name)
      identities = tenant.atua_transport_documents.where(driver_name_condition(name))
        .where.not(driver_document_digits: nil).distinct.pluck(:driver_name, :driver_document_digits)
        .select { |_driver_name, digits| digits.length == CPF_LENGTH }
      return [name, nil] unless identities.map(&:last).uniq.one?

      [identities.map { |driver_name, _digits| driver_name.squish.upcase }.max_by(&:length), identities.first.last]
    end

    def driver_name_condition(name)
      column = Atua::TransportDocument.arel_table[:driver_name]
      return column.matches(name) if name.length < TRUNCATED_NAME_LENGTH

      column.matches("#{Atua::TransportDocument.sanitize_sql_like(name)}%")
    end
  end
end
