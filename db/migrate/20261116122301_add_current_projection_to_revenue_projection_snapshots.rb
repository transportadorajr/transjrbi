class AddCurrentProjectionToRevenueProjectionSnapshots < ActiveRecord::Migration[8.1]
  def change
    add_column :revenue_projection_snapshots, :current_projected_cents, :bigint
    add_column :revenue_projection_snapshots, :current_low_cents, :bigint
    add_column :revenue_projection_snapshots, :current_high_cents, :bigint
    add_column :revenue_projection_snapshots, :current_reference_at, :datetime
    add_column :revenue_projection_snapshots, :current_refreshed_at, :datetime
  end
end
