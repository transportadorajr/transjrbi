class CreateFreightExpenses < ActiveRecord::Migration[8.1]
  def change
    create_enum :freight_expense_kind_type, %w[commission]

    create_table :freight_expenses do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :transport_document, null: false, foreign_key: { to_table: :atua_transport_documents }, index: false
      t.references :commission_rule, foreign_key: true
      t.enum :kind_type, enum_type: :freight_expense_kind_type, null: false
      t.bigint :base_cents, null: false
      t.bigint :icms_cents, null: false, default: 0
      t.decimal :percentage, precision: 7, scale: 4, null: false
      t.bigint :amount_cents, null: false
      t.datetime :calculated_at, null: false

      t.timestamps
    end

    add_index :freight_expenses, %i[transport_document_id kind_type], unique: true
  end
end
