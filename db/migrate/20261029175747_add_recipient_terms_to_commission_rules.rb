class AddRecipientTermsToCommissionRules < ActiveRecord::Migration[8.1]
  def change
    add_column :commission_rules, :recipient_terms, :string, array: true, default: [], null: false
  end
end
