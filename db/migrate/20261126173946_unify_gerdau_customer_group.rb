class UnifyGerdauCustomerGroup < ActiveRecord::Migration[8.1]
  GROUP_NAME = 'GERDAU'.freeze

  def up
    Tenant.find_each do |tenant|
      next unless tenant.customer_groups.exists?(name: GROUP_NAME) || tenant.atua_customers.by_name(GROUP_NAME).exists?

      CustomerGroups::UnifyCommand.call(tenant, GROUP_NAME, [GROUP_NAME])
    end
  end

  def down; end
end
