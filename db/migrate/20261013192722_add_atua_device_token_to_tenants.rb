class AddAtuaDeviceTokenToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :atua_device_token, :text
  end
end
