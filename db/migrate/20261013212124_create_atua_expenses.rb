class CreateAtuaExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :atua_expenses do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.references :atua_import, foreign_key: { to_table: :atua_imports, on_delete: :nullify }
      t.bigint :code, null: false
      t.datetime :posted_at
      t.date :posted_on
      t.date :document_on
      t.date :accounting_on
      t.date :settled_on
      t.bigint :movement_code
      t.date :movement_on
      t.bigint :payee_code
      t.string :payee_name
      t.string :payee_document
      t.string :payee_document_digits
      t.bigint :history_code
      t.string :history_name
      t.string :cash_account_name
      t.bigint :branch_code
      t.string :branch_name
      t.string :headquarters_name
      t.string :trip_expense_kind
      t.string :spending_kind
      t.string :document_model
      t.string :document_number
      t.string :document_series
      t.string :document_key
      t.string :description
      t.string :accounting_account
      t.string :accounting_classification
      t.bigint :amount_cents
      t.bigint :discount_cents
      t.bigint :total_cents
      t.bigint :net_amount_cents
      t.bigint :pis_credit_cents
      t.bigint :cofins_credit_cents
      t.bigint :withholdings_cents
      t.bigint :paid_cents
      t.bigint :icms_cents
      t.bigint :icms_credit_cents
      t.decimal :icms_credit_percentage, precision: 7, scale: 4
      t.string :plate
      t.string :vehicle_model
      t.string :trip_number
      t.date :trip_departure_on
      t.date :trip_arrival_on
      t.bigint :trip_driver_code
      t.string :trip_driver_name
      t.bigint :transport_document_code
      t.string :transport_document_number
      t.integer :transport_document_series
      t.integer :apportionment_count
      t.integer :installment_count
      t.datetime :attachment_at
      t.jsonb :raw_data, null: false, default: []
      t.datetime :imported_at, null: false
      t.datetime :removed_from_atua_at

      t.timestamps
    end

    add_index :atua_expenses, %i[tenant_id code], unique: true
    add_index :atua_expenses, %i[tenant_id posted_on]
    add_index :atua_expenses, %i[tenant_id plate]
    add_index :atua_expenses, %i[tenant_id payee_code]
    add_index :atua_expenses, %i[tenant_id history_code]
    add_index :atua_expenses, %i[tenant_id trip_number]
    add_index :atua_expenses, %i[tenant_id transport_document_code]
    add_index :atua_expenses, %i[tenant_id headquarters_name]
  end
end
