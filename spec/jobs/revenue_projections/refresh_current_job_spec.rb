require 'rails_helper'

RSpec.describe RevenueProjections::RefreshCurrentJob do
  let!(:tenant) { create(:tenant) }
  let!(:tenant_without_documents) { create(:tenant) }

  before { create(:atua_transport_document, tenant:) }

  it 'refreshes the current projections of the tenants with documents' do
    allow(RevenueProjections::RefreshCurrentCommand).to receive(:call).and_return(2)

    described_class.perform_now

    expect(RevenueProjections::RefreshCurrentCommand).to have_received(:call).with(tenant).once
    expect(RevenueProjections::RefreshCurrentCommand).not_to have_received(:call).with(tenant_without_documents)
  end

  it 'is scheduled every 30 minutes after the projection of the morning' do
    entry = GoodJob.configuration.cron.fetch(:revenue_projection_current)
    schedule = Fugit.parse_cron(entry.fetch(:cron))
    time = Time.zone.local(2026, 11, 12, 5)
    runs = Array.new(4) { time = schedule.next_time(time).to_t.in_time_zone }

    expect(entry.fetch(:class)).to eq('RevenueProjections::RefreshCurrentJob')
    expect(runs.map { it.strftime('%H:%M') }).to eq(%w[06:10 06:40 07:10 07:40])
  end
end
