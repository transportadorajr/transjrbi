class PurgeAtuaMovementsBeforeApril2026 < ActiveRecord::Migration[8.1]
  def up
    Tenant.find_each { |tenant| Atua::PurgeMovementsBeforeCommand.call(tenant) }
  end

  def down; end
end
