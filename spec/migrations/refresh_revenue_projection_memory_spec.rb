require 'rails_helper'
require Rails.root.join('db/migrate/20261113200540_refresh_revenue_projection_memory')

RSpec.describe RefreshRevenueProjectionMemory do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  it 'schedules the refresh of the revenue projection memory' do
    expect { migration.up }.to have_enqueued_job(RevenueProjections::RefreshMemoryJob).exactly(:once)
  end

  it 'does not schedule anything when rolling back' do
    expect { migration.down }.not_to have_enqueued_job(RevenueProjections::RefreshMemoryJob)
  end
end
