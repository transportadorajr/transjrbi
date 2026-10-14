class AddErrorTypeToAtuaImports < ActiveRecord::Migration[8.1]
  def change
    create_enum :atua_import_error_type, %w[configuration authentication session download spreadsheet layout conversion unexpected]

    add_column :atua_imports, :error_type, :enum, enum_type: :atua_import_error_type
    add_index :atua_imports, %i[tenant_id report_type finished_at]
  end
end
