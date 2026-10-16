class CreateAdminHttpRequests < ActiveRecord::Migration[8.1]
  def change
    create_enum :admin_http_request_integration_type, %w[atua tomtom]

    create_table :admin_http_requests do |t|
      t.enum :integration_type, enum_type: :admin_http_request_integration_type, null: false
      t.references :tenant, foreign_key: { on_delete: :nullify }
      t.references :atua_import, foreign_key: { on_delete: :nullify }
      t.uuid :trace_id, null: false
      t.integer :attempt, null: false, default: 1
      t.string :http_method, null: false
      t.text :url, null: false
      t.jsonb :request_headers, null: false, default: {}
      t.text :request_body
      t.integer :status_code
      t.string :status_message
      t.jsonb :response_headers, null: false, default: {}
      t.text :response_body
      t.string :response_content_type
      t.bigint :response_size
      t.boolean :response_binary, null: false, default: false
      t.boolean :response_truncated, null: false, default: false
      t.integer :duration_ms
      t.string :error_class
      t.text :error_message

      t.timestamps
    end

    add_index :admin_http_requests, :created_at
    add_index :admin_http_requests, :trace_id
    add_index :admin_http_requests, :status_code
    add_index :admin_http_requests, :integration_type
  end
end
