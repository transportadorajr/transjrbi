class RefreshRevenueProjectionMemory < ActiveRecord::Migration[8.1]
  def up
    RevenueProjections::RefreshMemoryJob.perform_later
  end

  def down; end
end
