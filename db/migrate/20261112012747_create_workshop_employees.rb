class CreateWorkshopEmployees < ActiveRecord::Migration[8.1]
  def change
    create_enum :workshop_employee_role_type, %w[mechanic supervisor]

    create_table :workshop_employees do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.enum :role_type, enum_type: :workshop_employee_role_type, null: false, default: 'mechanic'
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :workshop_employees, %i[tenant_id name], unique: true
  end
end
