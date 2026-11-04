class ReplaceCargoDestinationWithCargoDestinationTypeOnAtuaTransportDocuments < ActiveRecord::Migration[8.1]
  def up
    create_enum :atua_transport_document_cargo_destination_type, %w[national export import]
    add_column :atua_transport_documents, :cargo_destination_type, :enum, enum_type: :atua_transport_document_cargo_destination_type
    execute <<~SQL.squish
      UPDATE atua_transport_documents
      SET cargo_destination_type = CASE lower(cargo_destination)
        WHEN 'nacional' THEN 'national'
        WHEN 'exportação' THEN 'export'
        WHEN 'exportacao' THEN 'export'
        WHEN 'importação' THEN 'import'
        WHEN 'importacao' THEN 'import'
      END::atua_transport_document_cargo_destination_type
    SQL
    remove_column :atua_transport_documents, :cargo_destination
  end

  def down
    add_column :atua_transport_documents, :cargo_destination, :string
    execute <<~SQL.squish
      UPDATE atua_transport_documents
      SET cargo_destination = CASE cargo_destination_type
        WHEN 'national' THEN 'Nacional'
        WHEN 'export' THEN 'Exportação'
        WHEN 'import' THEN 'Importação'
      END
    SQL
    remove_column :atua_transport_documents, :cargo_destination_type
    drop_enum :atua_transport_document_cargo_destination_type
  end
end
