class CreateAtuaVehicles < ActiveRecord::Migration[8.1]
  def change
    create_table :atua_vehicles do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.references :atua_import, foreign_key: { to_table: :atua_imports, on_delete: :nullify }
      t.bigint :code, null: false
      t.string :plate
      t.string :category
      t.string :vehicle_kind
      t.bigint :vehicle_kind_code
      t.string :wheelset
      t.string :body
      t.bigint :brand_code
      t.string :brand
      t.string :model
      t.integer :manufacture_year
      t.integer :model_year
      t.string :renavam
      t.string :chassis
      t.string :color
      t.string :ownership
      t.bigint :owner_code
      t.string :owner_name
      t.string :owner_document
      t.string :owner_document_digits
      t.string :antt
      t.bigint :driver_code
      t.string :driver_name
      t.string :driver_document
      t.string :driver_document_digits
      t.string :driver_license
      t.string :risk_status
      t.date :data_expires_on
      t.datetime :source_updated_at
      t.string :status
      t.bigint :city_code
      t.string :city
      t.bigint :state_code
      t.string :state
      t.date :registered_month_on
      t.date :updated_month_on
      t.datetime :owner_whatsapp_at
      t.datetime :driver_whatsapp_at
      t.datetime :high_performance_at
      t.jsonb :raw_data, null: false, default: {}
      t.datetime :imported_at, null: false
      t.datetime :removed_from_atua_at

      t.timestamps
    end

    add_index :atua_vehicles, %i[tenant_id code], unique: true
    add_index :atua_vehicles, %i[tenant_id plate]
    add_index :atua_vehicles, %i[tenant_id owner_code]
    add_index :atua_vehicles, %i[tenant_id status]
  end
end
