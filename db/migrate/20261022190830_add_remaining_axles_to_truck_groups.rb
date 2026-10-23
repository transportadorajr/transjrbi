class AddRemainingAxlesToTruckGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :truck_groups, :remaining_axles, :boolean, null: false, default: false

    add_index :truck_groups, :tenant_id, unique: true, where: 'remaining_axles AND activated_at IS NOT NULL',
                                         name: 'index_truck_groups_on_remaining_axles'
  end
end
