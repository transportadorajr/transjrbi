class CreateRevenueGoals < ActiveRecord::Migration[8.1]
  def change
    create_enum :revenue_goal_target_type, %w[company vehicle customer_group]

    create_table :revenue_goals do |t|
      t.references :tenant, null: false, foreign_key: true
      t.date :month, null: false
      t.enum :target_type, enum_type: :revenue_goal_target_type, null: false
      t.string :plate
      t.references :customer_group, foreign_key: true
      t.bigint :amount_cents, null: false

      t.timestamps
    end

    add_index :revenue_goals, %i[tenant_id month target_type plate customer_group_id], unique: true, nulls_not_distinct: true,
                                                                                       name: 'index_revenue_goals_on_target'
  end
end
