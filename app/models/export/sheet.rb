module Export
  Sheet = Data.define(:name, :columns, :rows) do
    class << self
      def for(relation, name:, except: [], fields: [])
        excluded = except.map(&:to_s)

        new(name:, columns: relation.klass.export_columns.reject { |column| excluded.include?(column.name) } + fields, rows: relation)
      end
    end

    def to_h
      { name:, columns: columns.map(&:to_h), rows: rows.map { |row| columns.map { |column| column.value(row) } } }
    end
  end
end
