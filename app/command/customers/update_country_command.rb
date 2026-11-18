module Customers
  class UpdateCountryCommand
    class << self
      def call(customer, country_type)
        new(customer, country_type).call
      end
    end

    def initialize(customer, country_type)
      @customer = customer
      @country_type = country_type.presence
    end

    def call
      customer.transaction do
        customer.lock!
        next if unchanged?

        country_type ? edit : restore
      end

      customer.reload
    end

    private

    attr_reader :customer, :country_type

    def unchanged?
      return customer.country_edited_at.nil? if country_type.nil?

      customer.country_edited_at.present? && customer.country_type == country_type
    end

    def edit
      customer.update!(country_type:, country_edited_at: Time.current)
    end

    def restore
      customer.update!(country_type: nil, country_edited_at: nil)
      AssignCountryCommand.call(customer.tenant)
    end
  end
end
