module ProductGroups
  class AssignCommand
    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      ActiveRecord::Base.transaction do
        assigned = product_names_by_group.sum do |product_group_id, product_names|
          documents.where(product_name: product_names).where(table[:product_group_id].is_distinct_from(product_group_id))
            .update_all(product_group_id:)
        end

        assigned + unclassified_documents.update_all(product_group_id: nil)
      end
    end

    private

    attr_reader :tenant

    def documents
      tenant.atua_transport_documents
    end

    def unclassified_documents
      classified_names = product_names_by_group.values.flatten

      documents.where.not(product_group_id: nil)
        .where(table[:product_name].eq(nil).or(table[:product_name].not_in(classified_names.presence || [''])))
    end

    def product_names_by_group
      @product_names_by_group ||= documents.where.not(product_name: nil).distinct.pluck(:product_name)
        .group_by { |product_name| subgroup_ids_by_name[ProductGroup.compact(product_name)] }
        .except(nil)
    end

    def subgroup_ids_by_name
      @subgroup_ids_by_name ||= tenant.product_groups.classifying.order(:id).each_with_object({}) do |subgroup, ids|
        subgroup.compacted_product_names.each { |product_name| ids[product_name] ||= subgroup.id }
      end
    end

    def table
      Atua::TransportDocument.arel_table
    end
  end
end
