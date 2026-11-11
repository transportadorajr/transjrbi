class CreateHolidays < ActiveRecord::Migration[8.1]
  def change
    create_enum :holiday_scope_type, %w[national state municipal]
    create_enum :holiday_kind_type, %w[holiday bridge_day optional]

    create_table :holidays do |t|
      t.references :tenant, null: false, foreign_key: true
      t.date :date, null: false
      t.string :name, null: false
      t.enum :scope_type, enum_type: :holiday_scope_type, null: false, default: 'national'
      t.enum :kind_type, enum_type: :holiday_kind_type, null: false, default: 'holiday'

      t.timestamps
    end

    add_index :holidays, %i[tenant_id date], unique: true
  end
end
