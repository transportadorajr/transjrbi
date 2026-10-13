class CreateAtuaImports < ActiveRecord::Migration[8.1]
  def change
    create_enum :atua_import_report_type, %w[transport_documents manifests expenses customers vehicles]
    create_enum :atua_import_status_type, %w[pending running succeeded failed]

    create_table :atua_imports do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.enum :report_type, enum_type: :atua_import_report_type, null: false
      t.enum :status_type, enum_type: :atua_import_status_type, null: false, default: 'pending'
      t.date :start_date
      t.date :end_date
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :rows_read, null: false, default: 0
      t.integer :inserted_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :removed_count, null: false, default: 0
      t.text :error_message

      t.timestamps
    end

    add_index :atua_imports, %i[tenant_id report_type created_at]
    add_index :atua_imports, :status_type
  end
end
