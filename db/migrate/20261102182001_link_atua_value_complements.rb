class LinkAtuaValueComplements < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each do |tenant|
      Atua::LinkComplementsCommand.call(tenant)
      Atua::LinkExpensesCommand.call(tenant)
    end
  end

  def down; end
end
