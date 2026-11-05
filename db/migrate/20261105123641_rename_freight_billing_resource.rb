class RenameFreightBillingResource < ActiveRecord::Migration[8.1]
  SLUG = 'freight_billing'.freeze
  NAME = 'Faturamento'.freeze
  PREVIOUS_NAME = 'Faturamento de fretes'.freeze

  def up
    rename_resource(NAME)
  end

  def down
    rename_resource(PREVIOUS_NAME)
  end

  private

  def rename_resource(name)
    execute "UPDATE resources SET name = #{connection.quote(name)}, updated_at = NOW() WHERE slug = #{connection.quote(SLUG)}"
  end
end
