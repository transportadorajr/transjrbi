module LifeInsurances
  class SeedCommand
    PATH = Rails.root.join('db/seeds/life_insurances.json')

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
      policies = data.fetch('life_insurance_policies').to_h { |attributes| seed_policy(attributes) }

      data.fetch('life_insurances').each { |attributes| seed_life_insurance(attributes, policies) }
    end

    private

    attr_reader :tenant, :path

    def data
      @data ||= JSON.parse(File.read(path))
    end

    def seed_policy(attributes)
      company_type = attributes.fetch('company_type')
      policy = tenant.life_insurance_policies.find_or_create_by!(company_type:) do |new_policy|
        new_policy.assign_attributes(
          capital_cents: cents(attributes.fetch('capital')), premium_rate_per_mille: attributes.fetch('premium_rate_per_mille').to_d,
          spouse_percentage: attributes.fetch('spouse_percentage'), children_percentage: attributes.fetch('children_percentage'),
          funeral_assistance_cents: cents(attributes.fetch('funeral_assistance'))
        )
      end

      [company_type, policy]
    end

    def seed_life_insurance(attributes, policies)
      employee = tenant.employees.find_by(attributes.slice('company_type', 'registration'))
      return if employee.nil? || employee.life_insurances.exists?

      employee.life_insurances.create!(
        tenant:, life_insurance_policy: policies.fetch(employee.company_type),
        capital_cents: attributes['capital'] && cents(attributes['capital'])
      )
    end

    def cents(value)
      (value.to_d * 100).to_i
    end
  end
end
