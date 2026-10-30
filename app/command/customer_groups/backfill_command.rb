module CustomerGroups
  class BackfillCommand
    RENAMED_GROUPS = {
      'ARCELORMITTAL' => 'ARCELOR',
      'MOINHO REGIO' => 'RÉGIO',
    }.freeze
    GROUPS = {
      'TERRAFEC' => ['2JM', 'TERRAFEC', 'TERRINHA ALIMENTOS'],
      'VIRGINIA' => ['VIRGINIA'],
      'MOVISTAR' => ['MOVISTAR'],
      'CONSOLATA' => ['CONSOLATA'],
      'ARCELOR' => ['ARCELOR'],
      'RÉGIO' => ['MOINHO REGIO'],
      'USIMINAS' => ['USIMINAS'],
      'RIO AZUL' => ['REFARE'],
      'ALAMEDA' => ['ALFLEN'],
      'TRADIÇÃO' => ['ALIMENTOS TRADICAO'],
      'INDEMIL' => ['INDEMIL'],
      'UNIDAS' => ['UNIDAS DISTRIBUIDORA'],
      'PANORAMA' => ['PANORAMA MAT'],
      'COAGRU' => ['COAGRU'],
      'CASA DO TRIGO' => ['CASA DO TRIGO'],
      'ACB' => ['BEBIDAS ACB'],
      'BIGOLIN' => ['BIGOLIN'],
      'ARAUCO' => ['ARAUCO'],
      'GERDAU' => ['GERDAU'],
      'RUDOLF' => ['RUDOLF SIZING'],
      'MULTIAMIDOS' => ['MULTIAMIDOS'],
      'SOORO' => ['SOORO'],
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
      rename_groups
      groups = GROUPS.map { |name, terms| find_or_create_group(name, terms) }

      AssignCommand.call(tenant)
      groups.each { |group| RegroupCommand.call(group) }

      groups
    end

    private

    attr_reader :tenant

    def rename_groups
      RENAMED_GROUPS.each do |old_name, name|
        next if tenant.customer_groups.exists?(name:)

        tenant.customer_groups.find_by(name: old_name)&.update!(name:)
      end
    end

    def find_or_create_group(name, terms)
      group = tenant.customer_groups.create_with(activated_at: Time.current).find_or_create_by!(name:)
      group.update!(terms:) if group.terms.empty?
      group
    end
  end
end
