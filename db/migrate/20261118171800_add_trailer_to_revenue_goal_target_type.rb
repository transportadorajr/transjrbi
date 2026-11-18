class AddTrailerToRevenueGoalTargetType < ActiveRecord::Migration[8.1]
  def change
    add_enum_value :revenue_goal_target_type, 'trailer'
  end
end
