class AddCopiedFromToTonnageRates < ActiveRecord::Migration[8.1]
  def change
    add_reference :tonnage_rates, :copied_from, foreign_key: { to_table: :tonnage_rates }
  end
end
