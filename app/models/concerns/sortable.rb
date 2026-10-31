module Sortable
  extend ActiveSupport::Concern

  COLLATION = '"und-x-icu"'.freeze

  included do
    class_attribute :sortable_columns, instance_accessor: false, default: {}
  end

  class_methods do
    def sortable(name, expression = nil)
      expression ||= -> { sort_text(arel_table[name]) }

      self.sortable_columns = sortable_columns.merge(name.to_s => expression)
    end

    def sortable_column?(name)
      sortable_columns.key?(name.to_s)
    end

    def sorted_by(name, direction)
      expression = sortable_columns.fetch(name.to_s).call

      order(direction.to_s == 'desc' ? expression.desc.nulls_last : expression.asc.nulls_last)
    end

    def sort_text(expression)
      present_text = Arel::Nodes::NamedFunction.new('NULLIF', [expression, Arel::Nodes.build_quoted('')])

      Arel::Nodes::InfixOperation.new('COLLATE', present_text, Arel.sql(COLLATION))
    end
  end
end
