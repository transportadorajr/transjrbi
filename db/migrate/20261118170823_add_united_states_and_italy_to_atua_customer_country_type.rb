class AddUnitedStatesAndItalyToAtuaCustomerCountryType < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_enum_value :atua_customer_country_type, 'united_states', if_not_exists: true
    add_enum_value :atua_customer_country_type, 'italy', if_not_exists: true
  end

  def down
    execute <<~SQL.squish
      UPDATE atua_customers SET country_type = 'other' WHERE country_type IN ('united_states', 'italy')
    SQL
  end
end
