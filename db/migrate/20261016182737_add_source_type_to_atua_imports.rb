class AddSourceTypeToAtuaImports < ActiveRecord::Migration[8.1]
  def change
    create_enum :atua_import_source_type, %w[mock production upload]

    add_column :atua_imports, :source_type, :enum, enum_type: :atua_import_source_type
  end
end
