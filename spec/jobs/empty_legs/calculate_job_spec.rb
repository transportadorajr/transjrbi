require 'rails_helper'

RSpec.describe EmptyLegs::CalculateJob do
  let!(:tenant) { create(:tenant) }

  before { allow(EmptyLegs::CalculateAllCommand).to receive(:call).and_return([]) }

  it 'calculates the empty legs of the tenant from the start date' do
    described_class.perform_now(tenant.id, '2026-10-01')

    expect(EmptyLegs::CalculateAllCommand).to have_received(:call).with(tenant, start_date: '2026-10-01')
  end

  it 'gives up without the TomTom configuration' do
    allow(EmptyLegs::CalculateAllCommand).to receive(:call).and_raise(Tomtom::ConfigurationError)

    expect { described_class.perform_now(tenant.id) }.not_to raise_error
  end

  it 'retries later when TomTom refuses the request' do
    allow(EmptyLegs::CalculateAllCommand).to receive(:call).and_raise(Tomtom::RateLimitError)

    expect { described_class.perform_now(tenant.id) }.to have_enqueued_job(described_class).with(tenant.id)
  end

  context 'with the GoodJob adapter' do
    before { use_good_job_adapter(described_class) }

    it 'waits while the empty legs of the same tenant are being calculated' do
      mark_good_job_running(described_class.perform_later(tenant.id))
      waiting = described_class.perform_later(tenant.id, '2026-10-01')

      GoodJob.perform_inline

      expect(EmptyLegs::CalculateAllCommand).not_to have_received(:call)
      expect(good_job_record(waiting).finished_at).to be_nil
    end
  end
end
