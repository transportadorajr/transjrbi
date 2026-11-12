class CreateMaintenanceOrders < ActiveRecord::Migration[8.1]
  def change
    create_enum :maintenance_order_equipment_type,
                %w[truck_tractor trailer b_train road_train rigid_truck light_vehicle other]
    create_enum :maintenance_order_maintenance_type, %w[preventive corrective roadside inspection improvement]
    create_enum :maintenance_order_priority_type, %w[high medium low]
    create_enum :maintenance_order_execution_place_type, %w[internal_workshop third_party on_route]
    create_enum :maintenance_order_affected_system_type,
                %w[engine cooling fuel clutch transmission axles brakes suspension steering tires electrical
                   pneumatic cab_body implement lubrication other]
    create_enum :maintenance_order_release_test_type, %w[road_test yard_test not_applicable]
    create_enum :maintenance_order_status_type, %w[open in_progress waiting_parts finished cancelled]

    create_table :maintenance_orders do |t|
      t.references :tenant, null: false, foreign_key: true
      t.bigint :number, null: false
      t.string :plate, null: false
      t.datetime :opened_at, null: false
      t.integer :odometer_km
      t.decimal :hour_meter, precision: 10, scale: 1
      t.bigint :driver_code
      t.string :driver_name
      t.references :supervisor, foreign_key: { to_table: :workshop_employees }
      t.references :opened_by, foreign_key: { to_table: :users }
      t.enum :equipment_type, enum_type: :maintenance_order_equipment_type, null: false
      t.string :equipment_other
      t.enum :maintenance_type, enum_type: :maintenance_order_maintenance_type, null: false
      t.enum :priority_type, enum_type: :maintenance_order_priority_type, null: false, default: 'medium'
      t.boolean :vehicle_stopped, null: false, default: false
      t.enum :execution_place_type, enum_type: :maintenance_order_execution_place_type, null: false,
                                    default: 'internal_workshop'
      t.enum :affected_system_type, enum_type: :maintenance_order_affected_system_type, null: false
      t.text :reported_defect, null: false
      t.text :diagnosis
      t.text :performed_service
      t.enum :release_test_type, enum_type: :maintenance_order_release_test_type
      t.enum :status_type, enum_type: :maintenance_order_status_type, null: false, default: 'open'
      t.datetime :finished_at
      t.integer :next_preventive_km
      t.bigint :parts_total_cents, null: false, default: 0
      t.bigint :services_total_cents, null: false, default: 0
      t.bigint :total_cents, null: false, default: 0

      t.timestamps
    end

    add_index :maintenance_orders, %i[tenant_id number], unique: true
    add_index :maintenance_orders, %i[tenant_id plate]
    add_index :maintenance_orders, %i[tenant_id status_type]
  end
end
