module ProductGroups
  class BackfillCommand
    GROUPS = {
      'SIDERÚRGICO' => {
        'BOBINA' => ['BOBINA'],
        'VERGALHÃO' => ['VERGALHAO DE FERRO'],
        'FIO MÁQUINA' => ['FERRO (FIO MAQUINA/ VERGALHAO ROLO)', 'DIVERSOS - FIO MAQUINA'],
        'CHAPAS' => ['CHAPAS', 'DIVERSOS - CHAPAS'],
        'OUTROS METAIS' => ['FERRO MS', 'DIVERSOS - TELA SOLDADA', 'TUBO INOX', 'FIO DE COBRE'],
      },
      'ALIMENTÍCIO' => {
        'FARINHAS' => ['FARINHA DE TRIGO', 'FARINHAS', 'FARELO DE TRIGO'],
        'TRIGO EM GRÃOS' => ['TRIGO EM GRAOS'],
        'AMIDOS E FÉCULAS' => ['AMIDO DE MILHO', 'FECULA DE MANDIOCA', 'POLVILHO'],
        'AÇÚCAR E SAL' => %w[ACUCAR SAL],
        'ÓLEOS E GORDURAS' => ['MARGARINA', 'GORDURA VEGETAL HIDRIGENADA'],
        'ADITIVOS' => ['ACIDO CITRICO'],
      },
      'BEBIDAS' => {
        'BEBIDAS' => %w[BEBIDAS CERVEJA REFRIGERANTE],
        'VASILHAMES' => ['VASILHAME'],
      },
      'CONSTRUÇÃO' => {
        'PISOS' => ['PISOS'],
        'CIMENTO E ARGAMASSA' => ['CIMENTO', 'ARGAMASSA', 'CAL HIDRAULICO', 'GESSO'],
        'TELHAS' => ['TELHAS'],
        'MADEIRA' => ['LAMINAS DE MADEIRA'],
      },
      'CELULOSE E PAPEL' => {
        'CELULOSE' => ['CELULOSE', 'DIVERSOS - CELULOSE', 'DIVERSOS - CELULOSE FILTER GRADE FARDOS',
                       'DIVERSOS - CELULOSE FLUFF BOBINAS LARG 50CM L2 ACT', 'DIVERSOS - CELULOSE FLUFF BOBINAS LARG 50CM L2 BE'],
        'PAPEL' => ['PAPEL'],
      },
    }.freeze
    REMAINING_GROUP = 'DIVERSOS'.freeze

    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      return [] if tenant.product_groups.exists?

      groups = ProductGroup.transaction do
        known_groups = GROUPS.filter_map { |name, subgroups| create_group(name, subgroups) }

        [*known_groups, create_group(REMAINING_GROUP, REMAINING_GROUP => remaining_product_names(known_groups))].compact
      end
      AssignCommand.call(tenant)

      groups
    end

    private

    attr_reader :tenant

    def create_group(name, subgroups)
      found = subgroups.transform_values { |product_names| tenant_product_names(product_names) }.select { |_, product_names| product_names.any? }
      return if found.empty?

      tenant.product_groups.create!(name:, activated: true).tap do |group|
        found.each { |subgroup_name, product_names| group.subgroups.create!(tenant:, name: subgroup_name, product_names:, activated: true) }
      end
    end

    def remaining_product_names(groups)
      grouped = groups.flat_map { |group| group.subgroups.flat_map(&:product_names) }

      document_product_names - grouped
    end

    def tenant_product_names(product_names)
      compacted = product_names.map { |product_name| ProductGroup.compact(product_name) }

      document_product_names.select { |product_name| compacted.include?(ProductGroup.compact(product_name)) }
    end

    def document_product_names
      @document_product_names ||= tenant.atua_transport_documents.where.not(product_name: nil).distinct.order(:product_name).pluck(:product_name)
    end
  end
end
