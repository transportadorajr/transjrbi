class MarkAdvanceIcmsCustomerGroups < ActiveRecord::Migration[8.1]
  GROUPS = %w[GERDAU].freeze

  def up
    CustomerGroup.reset_column_information
    CustomerGroup.where(name: GROUPS, pays_advance_icms_at: nil).update_all(pays_advance_icms_at: Time.current, updated_at: Time.current)
  end

  def down; end
end
