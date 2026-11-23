class CreateWorkScheduleDays < ActiveRecord::Migration[8.1]
  def change
    create_enum :work_schedule_day_kind_type, %w[day_off leave]
    create_enum :work_schedule_day_leave_reason_type, %w[medical_appointment medical_certificate]

    create_table :work_schedule_days do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true, index: false
      t.references :city, foreign_key: { on_delete: :nullify }
      t.date :date, null: false
      t.enum :kind_type, enum_type: :work_schedule_day_kind_type, null: false
      t.enum :leave_reason_type, enum_type: :work_schedule_day_leave_reason_type
      t.text :notes

      t.timestamps
    end

    add_index :work_schedule_days, %i[employee_id date], unique: true
    add_index :work_schedule_days, %i[tenant_id date]
  end
end
