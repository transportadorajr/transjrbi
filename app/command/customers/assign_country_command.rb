module Customers
  class AssignCountryCommand
    TERMS = {
      'paraguay' => ['PARAGUAY', 'PARAGUAI', 'ASUNCION', 'ASSUNCION', 'ASSUNCAO', 'CIUDAD DEL ESTE', 'ENCARNACION', 'CAPIATA',
                     'FERNANDO DE LA MORA', 'HERNANDARIAS'],
      'argentina' => ['ARGENTINA', 'BUENOS AIRES', 'VILLA CONSTITUCION', 'SAN NICOLAS DE LOS ARROYOS', 'MAR DEL PLATA'],
      'uruguay' => %w[URUGUAY URUGUAI MONTEVIDEO],
      'chile' => %w[CHILE VALPARAISO],
      'bolivia' => ['BOLIVIA', 'SANTA CRUZ DE LA SIERRA', 'COCHABAMBA'],
    }.freeze
    ATTRIBUTES = %i[city name trade_name street complement district].freeze

    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      changed_customers.group_by(&:first).sum do |country_type, changes|
        tenant.atua_customers.where(id: changes.map(&:last)).update_all(country_type:, updated_at: Time.current)
      end
    end

    private

    attr_reader :tenant

    def changed_customers
      candidates.filter_map do |customer|
        country_type = country_for(customer)
        [country_type, customer.id] unless country_type == customer.country_type
      end
    end

    def candidates
      customers = tenant.atua_customers.country_not_edited

      customers.foreign.or(customers.where.not(country_type: nil)).select(:id, :state, :country_type, *ATTRIBUTES).order(:id)
    end

    def country_for(customer)
      return unless customer.foreign?

      texts = ATTRIBUTES.filter_map { |attribute| normalize(customer.public_send(attribute)).presence }

      texts.each do |text|
        country_type = TERMS.find { |_country, terms| terms.any? { |term| text.include?(" #{term} ") } }&.first
        return country_type if country_type
      end

      nil
    end

    def normalize(text)
      words = I18n.transliterate(text.to_s).upcase.gsub(/[^A-Z0-9]+/, ' ').squish
      return if words.empty?

      " #{words} "
    end
  end
end
