class AddWarningMessageToAtuaImports < ActiveRecord::Migration[8.1]
  def change
    add_column :atua_imports, :warning_message, :text
  end
end
