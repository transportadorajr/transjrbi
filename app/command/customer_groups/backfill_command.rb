module CustomerGroups
  class BackfillCommand
    GROUPS = {
      'TERRAFEC' => ['2JM', 'TERRAFEC', 'TERRINHA ALIMENTOS'],
      'VIRGINIA' => ['VIRGINIA'],
      'MOVISTAR' => ['MOVISTAR'],
      'CONSOLATA' => ['CONSOLATA'],
      'ARCELORMITTAL' => ['ARCELOR'],
      'MOINHO REGIO' => ['MOINHO REGIO'],
      'USIMINAS' => ['USIMINAS'],
    }.freeze

    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      groups = GROUPS.map { |name, terms| find_or_create_group(name, terms) }

      AssignCommand.call(tenant)
      groups.each { |group| RegroupCommand.call(group) }

      groups
    end

    private

    attr_reader :tenant

    def find_or_create_group(name, terms)
      group = tenant.customer_groups.create_with(activated_at: Time.current).find_or_create_by!(name:)
      group.update!(terms:) if group.terms.empty?
      group
    end
  end
end
