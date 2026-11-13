class CreateRevenueProjectionDayNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :revenue_projection_day_notes do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      t.date :date, null: false
      t.text :body, null: false

      t.timestamps
    end

    add_index :revenue_projection_day_notes, %i[tenant_id date], unique: true
  end
end
