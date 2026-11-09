module Export
  Sheet = Data.define(:name, :relation) do
    def columns
      relation.klass.export_columns
    end

    def to_h
      exported = columns

      { name:, columns: exported.map(&:to_h), rows: relation.map { |record| exported.map { |column| column.value(record) } } }
    end
  end
end
