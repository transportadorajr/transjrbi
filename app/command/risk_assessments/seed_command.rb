module RiskAssessments
  class SeedCommand
    PATH = Rails.root.join('db/seeds/risk_assessments.json')

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
      data.fetch('risk_assessments').each { |attributes| seed_risk_assessment(attributes) }
    end

    private

    attr_reader :tenant, :path

    def data
      @data ||= JSON.parse(File.read(path))
    end

    def seed_risk_assessment(attributes)
      employee = tenant.employees.find_by(attributes.slice('company_type', 'registration'))
      return if employee.nil?

      provider_type = attributes.fetch('provider_type')
      return if employee.risk_assessments.exists?(provider_type:)

      employee.risk_assessments.create!(
        tenant:, provider_type:, status_type: attributes['status_type'], score: attributes['score'],
        valid_until: attributes['valid_until'] && Date.iso8601(attributes['valid_until'])
      )
    end
  end
end
