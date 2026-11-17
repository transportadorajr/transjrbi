class CreateMaintenanceOrderSignatures < ActiveRecord::Migration[8.1]
  def change
    create_enum :maintenance_order_signature_signer_role_type, %w[supervisor mechanic]

    create_table :maintenance_order_signatures do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :maintenance_order, null: false, foreign_key: true
      t.references :workshop_employee, null: false, foreign_key: true
      t.references :signed_by, foreign_key: { to_table: :users }
      t.enum :signer_role_type, enum_type: :maintenance_order_signature_signer_role_type, null: false
      t.string :signer_name, null: false
      t.jsonb :strokes, null: false, default: []
      t.datetime :signed_at, null: false
      t.string :content_digest, null: false
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :maintenance_order_signatures, %i[maintenance_order_id signer_role_type workshop_employee_id], unique: true,
                                                                                                             name: 'index_maintenance_order_signatures_uniqueness'
  end
end
