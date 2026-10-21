require 'rails_helper'

RSpec.describe EmptyLegs::ScheduleCalculationCommand do
  include GoodJobHelpers

  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  before { use_good_job_adapter(EmptyLegs::CalculateJob) }

  def waiting_arguments
    GoodJob::Job.where(performed_at: nil, finished_at: nil).map { |job| job.serialized_params['arguments'] }
  end

  it 'schedules the calculation from the start date' do
    described_class.call(tenant.id, '2026-10-01')

    expect(waiting_arguments).to eq([[tenant.id, '2026-10-01']])
  end

  context 'with calculations of the tenant already waiting' do
    before do
      EmptyLegs::CalculateJob.perform_later(tenant.id, '2026-03-01')
      EmptyLegs::CalculateJob.perform_later(tenant.id, '2026-01-01')
      EmptyLegs::CalculateJob.perform_later(other_tenant.id, '2025-06-01')
    end

    it 'replaces them with a single calculation from the earliest start date' do
      expect { described_class.call(tenant.id, '2026-02-01') }.to change(GoodJob::Job, :count).by(-1)

      expect(waiting_arguments).to contain_exactly([other_tenant.id, '2025-06-01'], [tenant.id, '2026-01-01'])
    end

    it 'calculates the whole history when one of them has no start date' do
      EmptyLegs::CalculateJob.perform_later(tenant.id)

      described_class.call(tenant.id, '2026-02-01')

      expect(waiting_arguments).to contain_exactly([other_tenant.id, '2025-06-01'], [tenant.id, nil])
    end
  end

  context 'with a calculation of the tenant running' do
    let!(:running) { EmptyLegs::CalculateJob.perform_later(tenant.id, '2025-09-01') }

    before { mark_good_job_running(running) }

    it 'keeps it running and schedules the next one after it' do
      described_class.call(tenant.id, '2026-10-01')

      expect(good_job_record(running).finished_at).to be_nil
      expect(waiting_arguments).to eq([[tenant.id, '2026-10-01']])
    end
  end
end
