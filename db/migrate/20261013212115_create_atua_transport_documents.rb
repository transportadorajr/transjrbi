class CreateAtuaTransportDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :atua_transport_documents do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.references :atua_import, foreign_key: { to_table: :atua_imports, on_delete: :nullify }
      t.bigint :code, null: false
      t.string :number, null: false
      t.integer :series
      t.string :document_kind
      t.string :issue_kind
      t.string :service_kind
      t.integer :cfop
      t.string :cte_status
      t.string :access_key
      t.datetime :issued_at
      t.date :posted_on
      t.date :arrival_on
      t.date :due_on
      t.datetime :canceled_at
      t.string :cancellation_reason
      t.bigint :branch_code
      t.string :branch_name
      t.bigint :headquarters_code
      t.string :headquarters_name
      t.bigint :agency_code
      t.string :agency_name
      t.string :origin_city
      t.string :origin_state
      t.bigint :origin_city_code
      t.string :destination_city
      t.string :destination_state
      t.bigint :destination_city_code
      t.bigint :sender_code
      t.string :sender_name
      t.string :sender_document
      t.string :sender_document_digits
      t.bigint :recipient_code
      t.string :recipient_name
      t.string :recipient_document
      t.string :recipient_document_digits
      t.bigint :payer_code
      t.string :payer_name
      t.string :payer_document
      t.string :payer_document_digits
      t.bigint :taker_code
      t.string :taker_name
      t.bigint :consignee_code
      t.string :consignee_name
      t.string :consignee_document
      t.string :consignee_document_digits
      t.bigint :driver_code
      t.string :driver_name
      t.string :driver_document
      t.string :driver_document_digits
      t.bigint :vehicle_code
      t.string :plate
      t.string :trailer_plate
      t.integer :axles
      t.string :vehicle_ownership
      t.decimal :weight_tons, precision: 14, scale: 3
      t.decimal :weight_kg, precision: 14, scale: 2
      t.decimal :product_quantity, precision: 14, scale: 3
      t.string :product_name
      t.string :ncm
      t.bigint :goods_value_cents
      t.string :goods_invoice_numbers, array: true, null: false, default: []
      t.string :goods_invoice_keys, array: true, null: false, default: []
      t.string :complemented_number
      t.string :manifest_numbers, array: true, null: false, default: []
      t.string :ciot
      t.string :operational_unit
      t.string :cargo_destination
      t.string :route
      t.string :shipment_number
      t.string :billing_number
      t.datetime :charged_at
      t.datetime :nfse_pending_at
      t.bigint :freight_cents
      t.bigint :weight_freight_cents
      t.bigint :value_freight_cents
      t.bigint :ad_valorem_cents
      t.bigint :other_charges_cents
      t.bigint :toll_cents
      t.bigint :icms_base_cents
      t.bigint :icms_cents
      t.bigint :icms_st_cents
      t.bigint :federal_tax_cents
      t.bigint :ibs_cents
      t.bigint :cbs_cents
      t.bigint :result_cents
      t.bigint :driver_freight_cents
      t.bigint :advance_cents
      t.bigint :commission_cents
      t.bigint :insurance_cents
      t.bigint :cost_cents
      t.decimal :result_margin_percentage, precision: 7, scale: 4
      t.decimal :distance_km, precision: 14, scale: 2
      t.jsonb :raw_data, null: false, default: {}
      t.datetime :imported_at, null: false
      t.datetime :removed_from_atua_at

      t.timestamps
    end

    add_index :atua_transport_documents, %i[tenant_id code], unique: true
    add_index :atua_transport_documents, %i[tenant_id number series branch_name]
    add_index :atua_transport_documents, %i[tenant_id issued_at]
    add_index :atua_transport_documents, %i[tenant_id posted_on]
    add_index :atua_transport_documents, %i[tenant_id plate]
    add_index :atua_transport_documents, %i[tenant_id trailer_plate]
    add_index :atua_transport_documents, %i[tenant_id vehicle_code]
    add_index :atua_transport_documents, %i[tenant_id sender_code]
    add_index :atua_transport_documents, %i[tenant_id recipient_code]
    add_index :atua_transport_documents, %i[tenant_id payer_code]
    add_index :atua_transport_documents, %i[tenant_id taker_code]
    add_index :atua_transport_documents, %i[tenant_id consignee_code]
    add_index :atua_transport_documents, %i[tenant_id cte_status]
    add_index :atua_transport_documents, :manifest_numbers, using: :gin
  end
end
