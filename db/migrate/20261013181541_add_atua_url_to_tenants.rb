class AddAtuaUrlToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :atua_url, :string
  end
end
