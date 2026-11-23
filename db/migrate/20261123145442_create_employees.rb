class CreateEmployees < ActiveRecord::Migration[8.0]
  def change
    create_enum :employee_company_type, %w[transjr mme mm_espinola]
    create_enum :employee_gender_type, %w[female male]
    create_enum :employee_work_schedule_type, %w[five_two not_scheduled]

    create_table :employees do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :driver, foreign_key: true, index: { unique: true }
      t.references :workshop_employee, foreign_key: true, index: { unique: true }
      t.string :name, null: false
      t.string :nickname
      t.string :legal_id, null: false
      t.enum :company_type, enum_type: :employee_company_type, null: false
      t.string :registration
      t.string :role
      t.string :cost_center
      t.enum :gender_type, enum_type: :employee_gender_type, null: false
      t.date :born_on
      t.date :admitted_on
      t.enum :work_schedule_type, enum_type: :employee_work_schedule_type, null: false, default: 'five_two'
      t.datetime :activated_at, default: -> { 'CURRENT_TIMESTAMP' }

      t.timestamps
    end

    add_index :employees, %i[tenant_id legal_id], unique: true
  end
end
