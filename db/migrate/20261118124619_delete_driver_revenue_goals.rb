class DeleteDriverRevenueGoals < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM revenue_goals WHERE target_type = 'driver'"
  end

  def down; end
end
