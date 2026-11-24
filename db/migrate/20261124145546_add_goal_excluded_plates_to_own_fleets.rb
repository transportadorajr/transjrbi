class AddGoalExcludedPlatesToOwnFleets < ActiveRecord::Migration[8.1]
  def change
    add_column :own_fleets, :goal_excluded_plates, :string, array: true, default: [], null: false
  end
end
