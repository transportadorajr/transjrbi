module CustomerGroups
  class KeepActiveCommand
    class << self
      def call(tenant, names)
        new(tenant, names).call
      end
    end

    def initialize(tenant, names)
      @tenant = tenant
      @names = names
    end

    def call
      CustomerGroup.transaction do
        listed.not_activated.update_all(activated_at: Time.current, updated_at: Time.current)
        tenant.customer_groups.where.not(id: listed.select(:id)).activated.update_all(activated_at: nil, updated_at: Time.current)
      end

      tenant.customer_groups.activated
    end

    private

    attr_reader :tenant, :names

    def listed
      tenant.customer_groups.where(name: names)
    end
  end
end
