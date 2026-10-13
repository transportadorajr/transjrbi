class CreateAtuaCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :atua_customers do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.references :atua_import, foreign_key: { to_table: :atua_imports, on_delete: :nullify }
      t.bigint :code, null: false
      t.string :name
      t.string :trade_name
      t.string :document
      t.string :document_digits
      t.string :person_kind
      t.string :state_registration
      t.string :street
      t.string :complement
      t.string :district
      t.string :zip_code
      t.bigint :city_code
      t.string :city
      t.bigint :state_code
      t.string :state
      t.string :phone
      t.string :emails, array: true, null: false, default: []
      t.string :activity
      t.string :payment_method
      t.string :payment_term
      t.date :registered_on
      t.date :last_billed_on
      t.date :updated_month_on
      t.string :status
      t.datetime :whatsapp_at
      t.datetime :exporter_at
      t.datetime :simples_optant_at
      t.jsonb :raw_data, null: false, default: {}
      t.datetime :imported_at, null: false
      t.datetime :removed_from_atua_at

      t.timestamps
    end

    add_index :atua_customers, %i[tenant_id code], unique: true
    add_index :atua_customers, %i[tenant_id document_digits]
    add_index :atua_customers, %i[tenant_id status]
  end
end
