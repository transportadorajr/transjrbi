class CreateAtuaTollVouchers < ActiveRecord::Migration[8.1]
  def change
    create_table :atua_toll_vouchers do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.references :atua_import, foreign_key: { to_table: :atua_imports, on_delete: :nullify }
      t.string :code, null: false
      t.string :transport_document_number, null: false
      t.string :document_kind
      t.string :order_number
      t.date :ordered_on
      t.date :issued_on
      t.datetime :posted_at
      t.date :canceled_on
      t.string :plate
      t.bigint :branch_code
      t.string :branch_name
      t.bigint :issuer_code
      t.string :issuer_name
      t.string :driver_name
      t.string :payer_name
      t.string :payer_document
      t.string :payer_document_digits
      t.integer :axles
      t.bigint :toll_cents
      t.bigint :charged_toll_cents
      t.bigint :advance_cents
      t.bigint :admin_fee_cents
      t.bigint :total_cents
      t.jsonb :raw_data, null: false, default: {}
      t.datetime :imported_at, null: false
      t.datetime :removed_from_atua_at

      t.timestamps
    end

    add_index :atua_toll_vouchers, %i[tenant_id code], unique: true
    add_index :atua_toll_vouchers, %i[tenant_id transport_document_number branch_code]
    add_index :atua_toll_vouchers, %i[tenant_id issued_on]
  end
end
