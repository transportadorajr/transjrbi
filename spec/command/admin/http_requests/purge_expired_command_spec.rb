require 'rails_helper'

RSpec.describe Admin::HttpRequests::PurgeExpiredCommand do
  context 'with requests older and newer than 30 days' do
    let!(:recent) { create(:admin_http_request, created_at: 29.days.ago) }

    before { create_list(:admin_http_request, 2, created_at: 31.days.ago) }

    it 'deletes only the expired requests' do
      expect { described_class.call }.to change(Admin::HttpRequest, :count).by(-2)

      expect(Admin::HttpRequest.all).to eq([recent])
    end

    it 'does nothing when run again' do
      described_class.call

      expect(described_class.call).to eq(0)
      expect(Admin::HttpRequest.count).to eq(1)
    end
  end
end
