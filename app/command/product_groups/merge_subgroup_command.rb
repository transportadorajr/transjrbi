module ProductGroups
  class MergeSubgroupCommand
    class << self
      def call(tenant, source_name, target_name)
        new(tenant, source_name, target_name).call
      end
    end

    def initialize(tenant, source_name, target_name)
      @tenant = tenant
      @source_name = source_name
      @target_name = target_name
    end

    def call
      source = tenant.product_groups.nested.find_by(name: source_name)
      return tenant.product_groups.nested.find_by(name: target_name) if source.nil?

      target = ProductGroup.transaction { merge(source) }
      AssignCommand.call(tenant)

      target
    end

    private

    attr_reader :tenant, :source_name, :target_name

    def merge(source)
      target = source.parent.subgroups.find_by(name: target_name)
      return source.tap { source.update!(name: target_name) } if target.nil?

      target.update!(product_names: (target.product_names + source.product_names).uniq)
      source.destroy!

      target
    end
  end
end
