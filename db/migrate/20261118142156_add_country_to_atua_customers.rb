class AddCountryToAtuaCustomers < ActiveRecord::Migration[8.1]
  def change
    create_enum :atua_customer_country_type, %w[argentina paraguay uruguay chile bolivia other]

    add_column :atua_customers, :country_type, :enum, enum_type: :atua_customer_country_type
    add_column :atua_customers, :country_edited_at, :datetime
  end
end
