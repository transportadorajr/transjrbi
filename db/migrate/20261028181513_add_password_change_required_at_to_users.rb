class AddPasswordChangeRequiredAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :password_change_required_at, :datetime
  end
end
