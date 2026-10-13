class AddAtuaDeviceHashToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :atua_device_hash, :text
  end
end
