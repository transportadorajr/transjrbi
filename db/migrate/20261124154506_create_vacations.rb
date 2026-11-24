class CreateVacations < ActiveRecord::Migration[8.1]
  def change
    create_table :vacations do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.date :acquisition_start_on, null: false
      t.date :start_on, null: false
      t.date :end_on, null: false
      t.integer :sold_days, null: false, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :vacations, %i[tenant_id start_on]
    add_index :vacations, %i[employee_id start_on]
  end
end
