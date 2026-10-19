# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_19_144621) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "admin_http_request_integration_type", ["atua", "tomtom"]
  create_enum "atua_device_registration_status_type", ["code_sent", "confirmed", "failed"]
  create_enum "atua_import_error_type", ["configuration", "authentication", "device_verification", "session", "download", "spreadsheet", "layout", "conversion", "unexpected"]
  create_enum "atua_import_report_type", ["transport_documents", "manifests", "expenses", "customers", "vehicles"]
  create_enum "atua_import_source_type", ["mock", "production", "upload"]
  create_enum "atua_import_status_type", ["pending", "running", "succeeded", "failed"]
  create_enum "commission_rule_base_type", ["freight", "freight_without_icms"]
  create_enum "commission_rule_destination_type", ["national", "foreign"]
  create_enum "empty_leg_status_type", ["calculated", "unlocated", "unrouted"]
  create_enum "freight_expense_kind_type", ["commission", "tonnage", "insurance"]
  create_enum "location_precision_type", ["address", "city"]
  create_enum "user_type", ["owner", "admin", "operator"]

  create_table "accesses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "resource_id", null: false
    t.bigint "tenant_id", null: false
    t.boolean "reads", default: false, null: false
    t.boolean "creates", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resource_id"], name: "index_accesses_on_resource_id"
    t.index ["tenant_id"], name: "index_accesses_on_tenant_id"
    t.index ["user_id", "resource_id"], name: "index_accesses_on_user_id_and_resource_id", unique: true
    t.index ["user_id"], name: "index_accesses_on_user_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_http_requests", force: :cascade do |t|
    t.enum "integration_type", null: false, enum_type: "admin_http_request_integration_type"
    t.bigint "tenant_id"
    t.bigint "atua_import_id"
    t.uuid "trace_id", null: false
    t.integer "attempt", default: 1, null: false
    t.string "http_method", null: false
    t.text "url", null: false
    t.jsonb "request_headers", default: {}, null: false
    t.text "request_body"
    t.integer "status_code"
    t.string "status_message"
    t.jsonb "response_headers", default: {}, null: false
    t.text "response_body"
    t.string "response_content_type"
    t.bigint "response_size"
    t.boolean "response_binary", default: false, null: false
    t.boolean "response_truncated", default: false, null: false
    t.integer "duration_ms"
    t.string "error_class"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["atua_import_id"], name: "index_admin_http_requests_on_atua_import_id"
    t.index ["created_at"], name: "index_admin_http_requests_on_created_at"
    t.index ["integration_type"], name: "index_admin_http_requests_on_integration_type"
    t.index ["status_code"], name: "index_admin_http_requests_on_status_code"
    t.index ["tenant_id"], name: "index_admin_http_requests_on_tenant_id"
    t.index ["trace_id"], name: "index_admin_http_requests_on_trace_id"
  end

  create_table "admin_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "last_active_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_admin_sessions_on_token", unique: true
    t.index ["user_id"], name: "index_admin_sessions_on_user_id"
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
  end

  create_table "atua_customers", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "atua_import_id"
    t.bigint "code", null: false
    t.string "name"
    t.string "trade_name"
    t.string "document"
    t.string "document_digits"
    t.string "person_kind"
    t.string "state_registration"
    t.string "street"
    t.string "complement"
    t.string "district"
    t.string "zip_code"
    t.bigint "city_code"
    t.string "city"
    t.bigint "state_code"
    t.string "state"
    t.string "phone"
    t.string "emails", default: [], null: false, array: true
    t.string "activity"
    t.string "payment_method"
    t.string "payment_term"
    t.date "registered_on"
    t.date "last_billed_on"
    t.date "updated_month_on"
    t.string "status"
    t.datetime "whatsapp_at"
    t.datetime "exporter_at"
    t.datetime "simples_optant_at"
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "imported_at", null: false
    t.datetime "removed_from_atua_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "customer_group_id"
    t.index ["atua_import_id"], name: "index_atua_customers_on_atua_import_id"
    t.index ["customer_group_id"], name: "index_atua_customers_on_customer_group_id"
    t.index ["tenant_id", "code"], name: "index_atua_customers_on_tenant_id_and_code", unique: true
    t.index ["tenant_id", "document_digits"], name: "index_atua_customers_on_tenant_id_and_document_digits"
    t.index ["tenant_id", "status"], name: "index_atua_customers_on_tenant_id_and_status"
  end

  create_table "atua_device_registrations", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.enum "status_type", default: "code_sent", null: false, enum_type: "atua_device_registration_status_type"
    t.string "masked_email"
    t.text "session_state"
    t.datetime "expires_at", null: false
    t.datetime "confirmed_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_atua_device_registrations_on_tenant_id"
  end

  create_table "atua_expenses", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "atua_import_id"
    t.bigint "code", null: false
    t.datetime "posted_at"
    t.date "posted_on"
    t.date "document_on"
    t.date "accounting_on"
    t.date "settled_on"
    t.bigint "movement_code"
    t.date "movement_on"
    t.bigint "payee_code"
    t.string "payee_name"
    t.string "payee_document"
    t.string "payee_document_digits"
    t.bigint "history_code"
    t.string "history_name"
    t.string "cash_account_name"
    t.bigint "branch_code"
    t.string "branch_name"
    t.string "headquarters_name"
    t.string "trip_expense_kind"
    t.string "spending_kind"
    t.string "document_model"
    t.string "document_number"
    t.string "document_series"
    t.string "document_key"
    t.string "description"
    t.string "accounting_account"
    t.string "accounting_classification"
    t.bigint "amount_cents"
    t.bigint "discount_cents"
    t.bigint "total_cents"
    t.bigint "net_amount_cents"
    t.bigint "pis_credit_cents"
    t.bigint "cofins_credit_cents"
    t.bigint "withholdings_cents"
    t.bigint "paid_cents"
    t.bigint "icms_cents"
    t.bigint "icms_credit_cents"
    t.decimal "icms_credit_percentage", precision: 7, scale: 4
    t.string "plate"
    t.string "vehicle_model"
    t.string "trip_number"
    t.date "trip_departure_on"
    t.date "trip_arrival_on"
    t.bigint "trip_driver_code"
    t.string "trip_driver_name"
    t.bigint "transport_document_code"
    t.string "transport_document_number"
    t.integer "transport_document_series"
    t.integer "apportionment_count"
    t.integer "installment_count"
    t.datetime "attachment_at"
    t.jsonb "raw_data", default: [], null: false
    t.datetime "imported_at", null: false
    t.datetime "removed_from_atua_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cost_object_type"
    t.bigint "cost_object_id"
    t.index ["atua_import_id"], name: "index_atua_expenses_on_atua_import_id"
    t.index ["cost_object_type", "cost_object_id"], name: "index_atua_expenses_on_cost_object"
    t.index ["tenant_id", "code"], name: "index_atua_expenses_on_tenant_id_and_code", unique: true
    t.index ["tenant_id", "headquarters_name"], name: "index_atua_expenses_on_tenant_id_and_headquarters_name"
    t.index ["tenant_id", "history_code"], name: "index_atua_expenses_on_tenant_id_and_history_code"
    t.index ["tenant_id", "payee_code"], name: "index_atua_expenses_on_tenant_id_and_payee_code"
    t.index ["tenant_id", "plate"], name: "index_atua_expenses_on_tenant_id_and_plate"
    t.index ["tenant_id", "posted_on"], name: "index_atua_expenses_on_tenant_id_and_posted_on"
    t.index ["tenant_id", "transport_document_code"], name: "index_atua_expenses_on_tenant_id_and_transport_document_code"
    t.index ["tenant_id", "trip_number"], name: "index_atua_expenses_on_tenant_id_and_trip_number"
  end

  create_table "atua_imports", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.enum "report_type", null: false, enum_type: "atua_import_report_type"
    t.enum "status_type", default: "pending", null: false, enum_type: "atua_import_status_type"
    t.date "start_date"
    t.date "end_date"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.integer "rows_read", default: 0, null: false
    t.integer "inserted_count", default: 0, null: false
    t.integer "updated_count", default: 0, null: false
    t.integer "removed_count", default: 0, null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "warning_message"
    t.enum "error_type", enum_type: "atua_import_error_type"
    t.enum "source_type", enum_type: "atua_import_source_type"
    t.index ["status_type"], name: "index_atua_imports_on_status_type"
    t.index ["tenant_id", "report_type", "created_at"], name: "index_atua_imports_on_tenant_id_and_report_type_and_created_at"
    t.index ["tenant_id", "report_type", "finished_at"], name: "idx_on_tenant_id_report_type_finished_at_81434a2c5a"
  end

  create_table "atua_manifest_documents", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "atua_import_id"
    t.bigint "manifest_code", null: false
    t.string "branch_name"
    t.string "transport_document_number", null: false
    t.integer "transport_document_series"
    t.string "goods_invoice_numbers", default: [], null: false, array: true
    t.bigint "goods_value_cents"
    t.decimal "weight_kg", precision: 14, scale: 2
    t.decimal "weight_tons", precision: 14, scale: 3
    t.bigint "freight_cents"
    t.string "freight_payment"
    t.string "sender_name"
    t.string "recipient_name"
    t.string "origin_agency_name"
    t.string "origin_state"
    t.string "origin_city"
    t.string "destination_state"
    t.string "destination_city"
    t.decimal "calculated_distance_km", precision: 14, scale: 2
    t.decimal "document_distance_km", precision: 14, scale: 2
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "imported_at", null: false
    t.datetime "removed_from_atua_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["atua_import_id"], name: "index_atua_manifest_documents_on_atua_import_id"
    t.index ["tenant_id", "manifest_code", "transport_document_number", "transport_document_series"], name: "index_atua_manifest_documents_on_source_key", unique: true
    t.index ["tenant_id", "transport_document_number", "transport_document_series", "branch_name"], name: "index_atua_manifest_documents_on_transport_document"
  end

  create_table "atua_manifests", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "atua_import_id"
    t.bigint "code", null: false
    t.integer "model"
    t.string "number", null: false
    t.integer "series"
    t.string "branch_name"
    t.string "company_state"
    t.string "company_city"
    t.date "issued_on"
    t.date "departure_on"
    t.datetime "trip_started_at"
    t.datetime "closed_at"
    t.text "notes"
    t.string "plate"
    t.string "access_key"
    t.bigint "goods_value_cents"
    t.string "status"
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "imported_at", null: false
    t.datetime "removed_from_atua_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["atua_import_id"], name: "index_atua_manifests_on_atua_import_id"
    t.index ["tenant_id", "code"], name: "index_atua_manifests_on_tenant_id_and_code", unique: true
    t.index ["tenant_id", "departure_on"], name: "index_atua_manifests_on_tenant_id_and_departure_on"
    t.index ["tenant_id", "issued_on"], name: "index_atua_manifests_on_tenant_id_and_issued_on"
    t.index ["tenant_id", "number", "branch_name"], name: "index_atua_manifests_on_tenant_id_and_number_and_branch_name"
    t.index ["tenant_id", "plate"], name: "index_atua_manifests_on_tenant_id_and_plate"
    t.index ["tenant_id", "status"], name: "index_atua_manifests_on_tenant_id_and_status"
  end

  create_table "atua_transport_document_manifests", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "atua_import_id"
    t.bigint "transport_document_code", null: false
    t.string "manifest_number", null: false
    t.string "branch_name"
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "imported_at", null: false
    t.datetime "removed_from_atua_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["atua_import_id"], name: "index_atua_transport_document_manifests_on_atua_import_id"
    t.index ["tenant_id", "manifest_number", "branch_name"], name: "index_atua_transport_document_manifests_on_manifest"
    t.index ["tenant_id", "transport_document_code", "manifest_number"], name: "index_atua_transport_document_manifests_on_source_key", unique: true
  end

  create_table "atua_transport_documents", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "atua_import_id"
    t.bigint "code", null: false
    t.string "number", null: false
    t.integer "series"
    t.string "document_kind"
    t.string "issue_kind"
    t.string "service_kind"
    t.integer "cfop"
    t.string "cte_status"
    t.string "access_key"
    t.datetime "issued_at"
    t.date "posted_on"
    t.date "arrival_on"
    t.date "due_on"
    t.datetime "canceled_at"
    t.string "cancellation_reason"
    t.bigint "branch_code"
    t.string "branch_name"
    t.bigint "headquarters_code"
    t.string "headquarters_name"
    t.bigint "agency_code"
    t.string "agency_name"
    t.string "origin_city"
    t.string "origin_state"
    t.bigint "origin_city_code"
    t.string "destination_city"
    t.string "destination_state"
    t.bigint "destination_city_code"
    t.bigint "sender_code"
    t.string "sender_name"
    t.string "sender_document"
    t.string "sender_document_digits"
    t.bigint "recipient_code"
    t.string "recipient_name"
    t.string "recipient_document"
    t.string "recipient_document_digits"
    t.bigint "payer_code"
    t.string "payer_name"
    t.string "payer_document"
    t.string "payer_document_digits"
    t.bigint "taker_code"
    t.string "taker_name"
    t.bigint "consignee_code"
    t.string "consignee_name"
    t.string "consignee_document"
    t.string "consignee_document_digits"
    t.bigint "driver_code"
    t.string "driver_name"
    t.string "driver_document"
    t.string "driver_document_digits"
    t.bigint "vehicle_code"
    t.string "plate"
    t.string "trailer_plate"
    t.integer "axles"
    t.string "vehicle_ownership"
    t.decimal "weight_tons", precision: 14, scale: 3
    t.decimal "weight_kg", precision: 14, scale: 2
    t.decimal "product_quantity", precision: 14, scale: 3
    t.string "product_name"
    t.string "ncm"
    t.bigint "goods_value_cents"
    t.string "goods_invoice_numbers", default: [], null: false, array: true
    t.string "goods_invoice_keys", default: [], null: false, array: true
    t.string "complemented_number"
    t.string "manifest_numbers", default: [], null: false, array: true
    t.string "ciot"
    t.string "operational_unit"
    t.string "cargo_destination"
    t.string "route"
    t.string "shipment_number"
    t.string "billing_number"
    t.datetime "charged_at"
    t.datetime "nfse_pending_at"
    t.bigint "freight_cents"
    t.bigint "weight_freight_cents"
    t.bigint "value_freight_cents"
    t.bigint "ad_valorem_cents"
    t.bigint "other_charges_cents"
    t.bigint "toll_cents"
    t.bigint "icms_base_cents"
    t.bigint "icms_cents"
    t.bigint "icms_st_cents"
    t.bigint "federal_tax_cents"
    t.bigint "ibs_cents"
    t.bigint "cbs_cents"
    t.bigint "result_cents"
    t.bigint "driver_freight_cents"
    t.bigint "advance_cents"
    t.bigint "commission_cents"
    t.bigint "insurance_cents"
    t.bigint "cost_cents"
    t.decimal "result_margin_percentage", precision: 12, scale: 4
    t.decimal "distance_km", precision: 14, scale: 2
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "imported_at", null: false
    t.datetime "removed_from_atua_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["atua_import_id"], name: "index_atua_transport_documents_on_atua_import_id"
    t.index ["manifest_numbers"], name: "index_atua_transport_documents_on_manifest_numbers", using: :gin
    t.index ["tenant_id", "code"], name: "index_atua_transport_documents_on_tenant_id_and_code", unique: true
    t.index ["tenant_id", "consignee_code"], name: "index_atua_transport_documents_on_tenant_id_and_consignee_code"
    t.index ["tenant_id", "cte_status"], name: "index_atua_transport_documents_on_tenant_id_and_cte_status"
    t.index ["tenant_id", "issued_at"], name: "index_atua_transport_documents_on_tenant_id_and_issued_at"
    t.index ["tenant_id", "number", "series", "branch_name"], name: "idx_on_tenant_id_number_series_branch_name_82ba4806a5"
    t.index ["tenant_id", "payer_code"], name: "index_atua_transport_documents_on_tenant_id_and_payer_code"
    t.index ["tenant_id", "plate"], name: "index_atua_transport_documents_on_tenant_id_and_plate"
    t.index ["tenant_id", "posted_on"], name: "index_atua_transport_documents_on_tenant_id_and_posted_on"
    t.index ["tenant_id", "recipient_code"], name: "index_atua_transport_documents_on_tenant_id_and_recipient_code"
    t.index ["tenant_id", "sender_code"], name: "index_atua_transport_documents_on_tenant_id_and_sender_code"
    t.index ["tenant_id", "taker_code"], name: "index_atua_transport_documents_on_tenant_id_and_taker_code"
    t.index ["tenant_id", "trailer_plate"], name: "index_atua_transport_documents_on_tenant_id_and_trailer_plate"
    t.index ["tenant_id", "vehicle_code"], name: "index_atua_transport_documents_on_tenant_id_and_vehicle_code"
  end

  create_table "atua_vehicles", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "atua_import_id"
    t.bigint "code", null: false
    t.string "plate"
    t.string "category"
    t.string "vehicle_kind"
    t.bigint "vehicle_kind_code"
    t.string "wheelset"
    t.string "body"
    t.bigint "brand_code"
    t.string "brand"
    t.string "model"
    t.integer "manufacture_year"
    t.integer "model_year"
    t.string "renavam"
    t.string "chassis"
    t.string "color"
    t.string "ownership"
    t.bigint "owner_code"
    t.string "owner_name"
    t.string "owner_document"
    t.string "owner_document_digits"
    t.string "antt"
    t.bigint "driver_code"
    t.string "driver_name"
    t.string "driver_document"
    t.string "driver_document_digits"
    t.string "driver_license"
    t.string "risk_status"
    t.date "data_expires_on"
    t.datetime "source_updated_at"
    t.string "status"
    t.bigint "city_code"
    t.string "city"
    t.bigint "state_code"
    t.string "state"
    t.date "registered_month_on"
    t.date "updated_month_on"
    t.datetime "owner_whatsapp_at"
    t.datetime "driver_whatsapp_at"
    t.datetime "high_performance_at"
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "imported_at", null: false
    t.datetime "removed_from_atua_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["atua_import_id"], name: "index_atua_vehicles_on_atua_import_id"
    t.index ["tenant_id", "code"], name: "index_atua_vehicles_on_tenant_id_and_code", unique: true
    t.index ["tenant_id", "owner_code"], name: "index_atua_vehicles_on_tenant_id_and_owner_code"
    t.index ["tenant_id", "plate"], name: "index_atua_vehicles_on_tenant_id_and_plate"
    t.index ["tenant_id", "status"], name: "index_atua_vehicles_on_tenant_id_and_status"
  end

  create_table "commission_rules", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "customer_group_id", null: false
    t.string "name", null: false
    t.enum "destination_type", null: false, enum_type: "commission_rule_destination_type"
    t.enum "base_type", null: false, enum_type: "commission_rule_base_type"
    t.decimal "percentage", precision: 7, scale: 4, null: false
    t.string "cities", default: [], null: false, array: true
    t.datetime "activated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_group_id"], name: "index_commission_rules_on_customer_group_id"
    t.index ["tenant_id"], name: "index_commission_rules_on_tenant_id"
  end

  create_table "customer_groups", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "name", null: false
    t.string "terms", default: [], null: false, array: true
    t.datetime "activated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "name"], name: "index_customer_groups_on_tenant_id_and_name", unique: true
    t.index ["tenant_id"], name: "index_customer_groups_on_tenant_id"
  end

  create_table "empty_leg_transport_documents", force: :cascade do |t|
    t.bigint "empty_leg_id", null: false
    t.bigint "tenant_id", null: false
    t.bigint "transport_document_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["empty_leg_id", "transport_document_code"], name: "idx_on_empty_leg_id_transport_document_code_3c223e12fa", unique: true
    t.index ["tenant_id", "transport_document_code"], name: "idx_on_tenant_id_transport_document_code_eeccd5d4d4"
  end

  create_table "empty_legs", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "plate", null: false
    t.bigint "previous_manifest_code", null: false
    t.bigint "next_manifest_code", null: false
    t.bigint "origin_id"
    t.bigint "destination_id"
    t.bigint "road_route_id"
    t.decimal "distance_km", precision: 14, scale: 2
    t.enum "precision_type", enum_type: "location_precision_type"
    t.enum "status_type", null: false, enum_type: "empty_leg_status_type"
    t.datetime "calculated_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["destination_id"], name: "index_empty_legs_on_destination_id"
    t.index ["origin_id"], name: "index_empty_legs_on_origin_id"
    t.index ["road_route_id"], name: "index_empty_legs_on_road_route_id"
    t.index ["tenant_id", "next_manifest_code"], name: "index_empty_legs_on_tenant_id_and_next_manifest_code", unique: true
    t.index ["tenant_id", "plate"], name: "index_empty_legs_on_tenant_id_and_plate"
    t.index ["tenant_id", "previous_manifest_code"], name: "index_empty_legs_on_tenant_id_and_previous_manifest_code"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.string "feature_key", null: false
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "freight_expenses", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "transport_document_id", null: false
    t.bigint "commission_rule_id"
    t.enum "kind_type", null: false, enum_type: "freight_expense_kind_type"
    t.bigint "base_cents"
    t.bigint "icms_cents", default: 0, null: false
    t.decimal "percentage", precision: 7, scale: 4
    t.bigint "amount_cents", null: false
    t.datetime "calculated_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "tonnage_rate_id"
    t.decimal "weight_tons", precision: 14, scale: 3
    t.bigint "rate_cents"
    t.bigint "insurance_rate_id"
    t.decimal "iof_percentage", precision: 7, scale: 4
    t.bigint "iof_cents", default: 0, null: false
    t.index ["commission_rule_id"], name: "index_freight_expenses_on_commission_rule_id"
    t.index ["insurance_rate_id"], name: "index_freight_expenses_on_insurance_rate_id"
    t.index ["tenant_id"], name: "index_freight_expenses_on_tenant_id"
    t.index ["tonnage_rate_id"], name: "index_freight_expenses_on_tonnage_rate_id"
    t.index ["transport_document_id", "kind_type"], name: "index_freight_expenses_on_transport_document_id_and_kind_type", unique: true
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.jsonb "serialized_properties"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_discard"
    t.text "callback_queue_name"
    t.integer "callback_priority"
    t.datetime "enqueued_at"
    t.datetime "discarded_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
    t.index ["created_at", "id"], name: "index_good_job_batches_on_created_at_and_id", order: :desc
    t.index ["finished_at"], name: "index_good_job_batches_on_finished_at", where: "(finished_at IS NOT NULL)"
  end

  create_table "good_job_concurrency_claims", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "job_id", null: false
    t.uuid "locked_by_id"
    t.integer "state", limit: 2, null: false
    t.text "key", null: false
    t.index ["job_id"], name: "index_good_job_concurrency_claims_on_job_id"
    t.index ["key", "job_id"], name: "index_good_job_concurrency_claims_on_key_and_job_id", unique: true
    t.index ["key", "state", "created_at"], name: "index_good_job_concurrency_claims_for_promotion"
    t.index ["locked_by_id"], name: "index_good_job_concurrency_claims_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id", null: false
    t.text "job_class"
    t.text "queue_name"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.text "error"
    t.integer "error_event", limit: 2
    t.text "error_backtrace", array: true
    t.uuid "process_id"
    t.interval "duration"
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
    t.index ["scheduled_at"], name: "index_good_job_executions_on_scheduled_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "state"
    t.integer "lock_type", limit: 2
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "key"
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "queue_name"
    t.integer "priority"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "performed_at"
    t.datetime "finished_at"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id"
    t.text "concurrency_key"
    t.text "cron_key"
    t.uuid "retried_good_job_id"
    t.datetime "cron_at"
    t.uuid "batch_id"
    t.uuid "batch_callback_id"
    t.boolean "is_discrete"
    t.integer "executions_count"
    t.text "job_class"
    t.integer "error_event", limit: 2
    t.text "labels", array: true
    t.uuid "locked_by_id"
    t.datetime "locked_at"
    t.integer "lock_type", limit: 2
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id_unfinished", where: "((batch_callback_id IS NOT NULL) AND (finished_at IS NULL))"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id_unfinished", where: "((batch_id IS NOT NULL) AND (finished_at IS NULL))"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["created_at"], name: "index_good_jobs_on_created_at"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, order: { cron_at: "DESC NULLS LAST" }, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at_only", where: "(finished_at IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_on_discarded", order: :desc, where: "((finished_at IS NOT NULL) AND (error IS NOT NULL))"
    t.index ["id"], name: "index_good_jobs_on_unfinished_or_errored", where: "((finished_at IS NULL) OR (error IS NOT NULL))"
    t.index ["job_class", "finished_at"], name: "index_good_jobs_on_discarded_job_class", where: "((finished_at IS NOT NULL) AND (error IS NOT NULL))"
    t.index ["job_class"], name: "index_good_jobs_on_job_class"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_for_candidate_dequeue_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_on_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["queue_name", "priority", "created_at"], name: "index_good_jobs_dequeue_by_queue", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "priority", "scheduled_at"], name: "index_good_jobs_dequeue_by_queue_scheduled_at", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at", "id"], name: "index_good_jobs_on_queue_name_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["queue_name"], name: "index_good_jobs_on_queue_name"
    t.index ["scheduled_at", "queue_name"], name: "index_good_jobs_on_scheduled_at_and_queue_name"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "insurance_rates", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.date "valid_from", null: false
    t.decimal "insurance_percentage", precision: 7, scale: 4, null: false
    t.decimal "iof_percentage", precision: 7, scale: 4, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "valid_from"], name: "index_insurance_rates_on_tenant_id_and_valid_from", unique: true
    t.index ["tenant_id"], name: "index_insurance_rates_on_tenant_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "lookup_key", null: false
    t.string "street"
    t.string "city", null: false
    t.string "state", null: false
    t.decimal "latitude", precision: 10, scale: 7, null: false
    t.decimal "longitude", precision: 10, scale: 7, null: false
    t.enum "precision_type", null: false, enum_type: "location_precision_type"
    t.string "formatted_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["latitude", "longitude"], name: "index_locations_on_latitude_and_longitude"
    t.index ["lookup_key"], name: "index_locations_on_lookup_key", unique: true
  end

  create_table "resources", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.boolean "writable", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_resources_on_slug", unique: true
  end

  create_table "road_routes", force: :cascade do |t|
    t.bigint "origin_id", null: false
    t.bigint "destination_id", null: false
    t.decimal "distance_km", precision: 14, scale: 2, null: false
    t.integer "travel_time_seconds"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["destination_id"], name: "index_road_routes_on_destination_id"
    t.index ["origin_id", "destination_id"], name: "index_road_routes_on_origin_id_and_destination_id", unique: true
  end

  create_table "tenants", force: :cascade do |t|
    t.string "name", null: false
    t.string "legal_id", null: false
    t.string "trade_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "atua_url"
    t.text "atua_device_token"
    t.text "atua_device_hash"
    t.index ["legal_id"], name: "index_tenants_on_legal_id", unique: true
  end

  create_table "tonnage_rates", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "customer_group_id", null: false
    t.string "name", null: false
    t.string "nickname"
    t.string "origin_city", null: false
    t.string "origin_state", null: false
    t.date "valid_month", null: false
    t.bigint "rate_cents", null: false
    t.datetime "activated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_group_id"], name: "index_tonnage_rates_on_customer_group_id"
    t.index ["tenant_id", "valid_month"], name: "index_tonnage_rates_on_tenant_id_and_valid_month"
    t.index ["tenant_id"], name: "index_tonnage_rates_on_tenant_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "tenant_id", null: false
    t.string "name", null: false
    t.string "phone"
    t.enum "user_type", default: "operator", null: false, enum_type: "user_type"
    t.datetime "activated_at"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["tenant_id"], name: "index_users_on_tenant_id"
    t.index ["tenant_id"], name: "index_users_on_tenant_id_where_owner_user_type", unique: true, where: "(user_type = 'owner'::user_type)"
  end

  add_foreign_key "accesses", "resources"
  add_foreign_key "accesses", "tenants"
  add_foreign_key "accesses", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "admin_http_requests", "atua_imports", on_delete: :nullify
  add_foreign_key "admin_http_requests", "tenants", on_delete: :nullify
  add_foreign_key "admin_sessions", "admin_users", column: "user_id"
  add_foreign_key "atua_customers", "atua_imports", on_delete: :nullify
  add_foreign_key "atua_customers", "customer_groups"
  add_foreign_key "atua_customers", "tenants"
  add_foreign_key "atua_device_registrations", "tenants"
  add_foreign_key "atua_expenses", "atua_imports", on_delete: :nullify
  add_foreign_key "atua_expenses", "tenants"
  add_foreign_key "atua_imports", "tenants"
  add_foreign_key "atua_manifest_documents", "atua_imports", on_delete: :nullify
  add_foreign_key "atua_manifest_documents", "tenants"
  add_foreign_key "atua_manifests", "atua_imports", on_delete: :nullify
  add_foreign_key "atua_manifests", "tenants"
  add_foreign_key "atua_transport_document_manifests", "atua_imports", on_delete: :nullify
  add_foreign_key "atua_transport_document_manifests", "tenants"
  add_foreign_key "atua_transport_documents", "atua_imports", on_delete: :nullify
  add_foreign_key "atua_transport_documents", "tenants"
  add_foreign_key "atua_vehicles", "atua_imports", on_delete: :nullify
  add_foreign_key "atua_vehicles", "tenants"
  add_foreign_key "commission_rules", "customer_groups"
  add_foreign_key "commission_rules", "tenants"
  add_foreign_key "customer_groups", "tenants"
  add_foreign_key "empty_leg_transport_documents", "empty_legs", on_delete: :cascade
  add_foreign_key "empty_leg_transport_documents", "tenants"
  add_foreign_key "empty_legs", "locations", column: "destination_id"
  add_foreign_key "empty_legs", "locations", column: "origin_id"
  add_foreign_key "empty_legs", "road_routes"
  add_foreign_key "empty_legs", "tenants"
  add_foreign_key "freight_expenses", "atua_transport_documents", column: "transport_document_id"
  add_foreign_key "freight_expenses", "commission_rules"
  add_foreign_key "freight_expenses", "insurance_rates"
  add_foreign_key "freight_expenses", "tenants"
  add_foreign_key "freight_expenses", "tonnage_rates"
  add_foreign_key "insurance_rates", "tenants"
  add_foreign_key "road_routes", "locations", column: "destination_id"
  add_foreign_key "road_routes", "locations", column: "origin_id"
  add_foreign_key "tonnage_rates", "customer_groups"
  add_foreign_key "tonnage_rates", "tenants"
  add_foreign_key "users", "tenants"
end
