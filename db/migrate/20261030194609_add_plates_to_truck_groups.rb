class AddPlatesToTruckGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :truck_groups, :plates, :string, array: true, default: [], null: false
  end
end
