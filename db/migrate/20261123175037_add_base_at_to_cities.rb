class AddBaseAtToCities < ActiveRecord::Migration[8.1]
  def change
    add_column :cities, :base_at, :datetime
  end
end
