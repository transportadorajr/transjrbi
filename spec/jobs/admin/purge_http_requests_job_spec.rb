require 'rails_helper'

RSpec.describe Admin::PurgeHttpRequestsJob do
  it 'deletes the expired requests' do
    create(:admin_http_request, created_at: 31.days.ago)
    recent = create(:admin_http_request)

    described_class.perform_now

    expect(Admin::HttpRequest.all).to eq([recent])
  end

  it 'is scheduled every day at 3h45' do
    expect(GoodJob.configuration.cron.fetch(:admin_http_requests).slice(:cron, :class))
      .to eq(cron: '45 3 * * * America/Sao_Paulo', class: 'Admin::PurgeHttpRequestsJob')
  end
end
