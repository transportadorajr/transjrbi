class AddCapitalChangedOnToLifeInsurances < ActiveRecord::Migration[8.1]
  def change
    add_column :life_insurances, :capital_changed_on, :date
  end
end
