class MarkExportSummaryCustomerGroups < ActiveRecord::Migration[8.1]
  GROUPS = %w[ARCELOR USIMINAS].freeze

  def up
    CustomerGroup.reset_column_information
    CustomerGroup.where(name: GROUPS, in_export_summary_at: nil).update_all(in_export_summary_at: Time.current, updated_at: Time.current)
  end

  def down; end
end
