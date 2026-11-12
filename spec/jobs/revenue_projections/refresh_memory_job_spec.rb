require 'rails_helper'

RSpec.describe RevenueProjections::RefreshMemoryJob do
  let!(:tenant) { create(:tenant) }
  let!(:tenant_without_documents) { create(:tenant) }

  before { create(:atua_transport_document, tenant:) }

  it 'refreshes the memory of the tenants with documents' do
    allow(RevenueProjections::RefreshMemoryCommand).to receive(:call).and_return(1)

    described_class.perform_now

    expect(RevenueProjections::RefreshMemoryCommand).to have_received(:call).with(tenant).once
    expect(RevenueProjections::RefreshMemoryCommand).not_to have_received(:call).with(tenant_without_documents)
  end

  it 'is scheduled every day at 6h' do
    expect(GoodJob.configuration.cron.fetch(:revenue_projection_memory).slice(:cron, :class))
      .to eq(cron: '0 6 * * * America/Sao_Paulo', class: 'RevenueProjections::RefreshMemoryJob')
  end
end
