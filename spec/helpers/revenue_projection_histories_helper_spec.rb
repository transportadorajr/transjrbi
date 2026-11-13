require 'rails_helper'

RSpec.describe RevenueProjectionHistoriesHelper do
  describe '#revenue_projection_period_link_class' do
    it 'highlights the selected period' do
      expect(helper.revenue_projection_period_link_class('week', 'week')).to eq('btn btn-sm btn-primary')
      expect(helper.revenue_projection_period_link_class('month', 'week')).to eq('btn btn-sm btn-outline-secondary')
    end
  end
end
