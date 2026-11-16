class AddDriverToRevenueGoals < ActiveRecord::Migration[8.1]
  def change
    add_enum_value :revenue_goal_target_type, 'driver'

    add_column :revenue_goals, :driver_code, :bigint

    remove_index :revenue_goals, %i[tenant_id month target_type plate customer_group_id macro_region_id], unique: true, nulls_not_distinct: true,
                                                                                                          name: 'index_revenue_goals_on_target'
    add_index :revenue_goals, %i[tenant_id month target_type plate customer_group_id macro_region_id driver_code], unique: true, nulls_not_distinct: true,
                                                                                                                   name: 'index_revenue_goals_on_target'
  end
end
