class EnableFeatureFlagsGlobally < ActiveRecord::Migration[8.1]
  FEATURES = %i[
    trips_dashboard
    revenue_projection
    revenue_goals
    freight_month_comparison
    export_summary
    maintenance
    maintenance_order_signatures
    hr
    xlsx_export
  ].freeze

  def up
    FEATURES.each { |feature| Flipper.enable(feature) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
