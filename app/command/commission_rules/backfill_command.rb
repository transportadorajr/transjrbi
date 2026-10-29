module CommissionRules
  class BackfillCommand
    GROUP_NAME = 'USIMINAS'.freeze
    GROUP_TERMS = %w[USIMINAS].freeze
    RULES = [
      { name: 'Nacional', destination_type: 'national', base_type: 'freight_without_icms', percentage: '2.0', cities: [] },
      {
        name: 'Argentina', destination_type: 'foreign', base_type: 'freight', percentage: '1.3',
        cities: ['Buenos Aires', 'Puerto Iguazú', 'Rosario'], recipient_terms: %w[FERROSIDER ACINDAR SIAT TERNIUM]
      },
      {
        name: 'Paraguai', destination_type: 'foreign', base_type: 'freight', percentage: '1.5', cities: ['Asunción', 'Ciudad del Este'],
        recipient_terms: %w[LACERIE GALLO ACEROS FERROPAR CJX ELIN FATA WADRA MERCOFER MONICA PERFILADOS]
      },
    ].freeze

    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      group = find_or_create_group
      return fill_recipient_terms(group) if group.commission_rules.exists?

      CustomerGroups::RegroupCommand.call(group)
      rules = RULES.map { |attributes| group.commission_rules.create!(tenant:, activated_at: Time.current, **attributes) }
      FreightExpenses::CalculateCommissionsCommand.call(tenant)

      rules
    end

    private

    attr_reader :tenant

    def fill_recipient_terms(group)
      rules = group.commission_rules.order(:id).to_a
      filled = rules.select(&:foreign?).select { |rule| rule.recipient_terms.empty? }.filter_map do |rule|
        terms = RULES.find { |attributes| attributes[:name] == rule.name }&.fetch(:recipient_terms, nil)
        rule.update!(recipient_terms: terms) if terms
      end
      FreightExpenses::CalculateCommissionsCommand.call(tenant) if filled.any?

      rules
    end

    def find_or_create_group
      matching_group = tenant.customer_groups.with_terms.order(:id).find { |group| group.match?(GROUP_NAME) }
      return matching_group if matching_group

      group = tenant.customer_groups.create_with(activated_at: Time.current).find_or_create_by!(name: GROUP_NAME)
      group.update!(terms: GROUP_TERMS) if group.terms.empty?
      group
    end
  end
end
