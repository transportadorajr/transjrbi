class AddIssuerToAtuaTransportDocuments < ActiveRecord::Migration[8.1]
  def up
    add_column :atua_transport_documents, :issuer_code, :integer
    add_column :atua_transport_documents, :issuer_name, :string
    add_index :atua_transport_documents, %i[tenant_id issuer_code]

    execute <<~SQL.squish
      UPDATE atua_transport_documents
      SET issuer_code = ROUND((raw_data->>'cd_pessoa_usuario')::numeric)::integer,
          issuer_name = NULLIF(TRIM(raw_data->>'nm_pessoa_usuario'), '')
      WHERE raw_data->>'cd_pessoa_usuario' ~ '^[0-9]+(\\.[0-9]+)?$'
    SQL
  end

  def down
    remove_index :atua_transport_documents, %i[tenant_id issuer_code]
    remove_column :atua_transport_documents, :issuer_name
    remove_column :atua_transport_documents, :issuer_code
  end
end
