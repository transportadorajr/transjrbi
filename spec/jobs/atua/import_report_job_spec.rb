require 'rails_helper'

RSpec.describe Atua::ImportReportJob do
  let!(:tenant) { create(:tenant) }
  let(:start_date) { Date.new(2026, 10, 1) }
  let(:end_date) { Date.new(2026, 10, 13) }

  before { allow(Atua::ImportReportCommand).to receive(:call).and_return([]) }

  describe '#perform' do
    it 'imports the report of the tenant raising the errors' do
      described_class.perform_now(tenant.id, 'manifests', start_date, end_date)

      expect(Atua::ImportReportCommand).to have_received(:call)
        .with(tenant, 'manifests', start_date:, end_date:, raise_errors: true)
    end

    it 'imports a registry without period' do
      described_class.perform_now(tenant.id, 'customers')

      expect(Atua::ImportReportCommand).to have_received(:call)
        .with(tenant, 'customers', start_date: nil, end_date: nil, raise_errors: true)
    end

    it 'runs a job enqueued with the former production access argument' do
      described_class.perform_now(tenant.id, 'manifests', start_date, end_date, production_access: true)

      expect(Atua::ImportReportCommand).to have_received(:call)
        .with(tenant, 'manifests', start_date:, end_date:, raise_errors: true)
    end
  end

  describe 'error handling' do
    let(:now) { Time.zone.local(2026, 10, 14, 10) }

    around { |example| travel_to(now) { example.run } }

    [Atua::AuthenticationError, Atua::ConfigurationError].each do |error_class|
      it "discards the job without retrying on #{error_class.name.demodulize}" do
        allow(Atua::ImportReportCommand).to receive(:call).and_raise(error_class, 'Login recusado')

        expect { described_class.perform_now(tenant.id, 'manifests', start_date, end_date) }.not_to raise_error
        expect(described_class).not_to have_been_enqueued
      end
    end

    {
      'a server error' => Atua::DownloadError.new('HTTP 503', status: 503),
      'a network failure' => Atua::SessionError.new('Timeout::Error'),
    }.each do |description, error|
      it "retries #{description} after a long wait" do
        allow(Atua::ImportReportCommand).to receive(:call).and_raise(error)

        described_class.perform_now(tenant.id, 'manifests', start_date, end_date)

        expect(described_class).to have_been_enqueued.with(tenant.id, 'manifests', start_date, end_date)
        scheduled_at = Time.zone.at(enqueued_jobs.sole['scheduled_at'].then { |value| Time.zone.parse(value) })
        expect(scheduled_at).to be_between(now + 30.minutes, now + 35.minutes)
      end
    end

    it 'gives up after three attempts' do
      allow(Atua::ImportReportCommand).to receive(:call).and_raise(Atua::DownloadError.new('HTTP 502', status: 502))
      job = described_class.new(tenant.id, 'manifests', start_date, end_date)
      job.exception_executions = { '[Atua::UnavailableError]' => 2 }

      expect { job.perform_now }.to raise_error(Atua::UnavailableError, 'HTTP 502')
      expect(described_class).not_to have_been_enqueued
    end

    it 'does not retry an answer that is not a spreadsheet' do
      allow(Atua::ImportReportCommand).to receive(:call).and_raise(Atua::DownloadError.new('Não veio em Excel', status: 200))

      expect { described_class.perform_now(tenant.id, 'manifests', start_date, end_date) }
        .to raise_error(Atua::DownloadError, 'Não veio em Excel')
      expect(described_class).not_to have_been_enqueued
    end
  end

  describe 'concurrency' do
    it 'labels the job by tenant and report, by period and by the shared Atua session' do
      expect(described_class.new(tenant.id, 'manifests', start_date, end_date).good_job_labels).to eq(
        ["atua-import:#{tenant.id}:manifests", "atua-import:#{tenant.id}:manifests:2026-10-01:2026-10-13", 'atua-session'],
      )
      expect(described_class.new(tenant.id, 'customers', nil, nil).good_job_labels).to eq(
        ["atua-import:#{tenant.id}:customers", "atua-import:#{tenant.id}:customers::", 'atua-session'],
      )
    end

    context 'with the GoodJob adapter' do
      let(:other_tenant) { create(:tenant) }

      before { use_good_job_adapter(described_class) }

      it 'does not enqueue the same import twice while it waits' do
        first = described_class.perform_later(tenant.id, 'manifests', start_date, end_date)
        repeated = described_class.perform_later(tenant.id, 'manifests', start_date, end_date)
        other_period = described_class.perform_later(tenant.id, 'manifests', Date.new(2026, 9, 1), Date.new(2026, 9, 30))

        expect(first).to be_successfully_enqueued
        expect(repeated).to be(false)
        expect(other_period).to be_successfully_enqueued
        expect(GoodJob::Job.where(job_class: described_class.name).count).to eq(2)
      end

      it 'runs the import when nothing else is running' do
        job = described_class.perform_later(tenant.id, 'manifests', start_date, end_date)

        GoodJob.perform_inline

        expect(Atua::ImportReportCommand).to have_received(:call).once
        expect(good_job_record(job).finished_at).to be_present
      end

      it 'waits while the same report of the tenant is being imported' do
        mark_good_job_running(described_class.perform_later(tenant.id, 'manifests', Date.new(2026, 9, 1), Date.new(2026, 9, 30)))
        waiting = described_class.perform_later(tenant.id, 'manifests', start_date, end_date)

        GoodJob.perform_inline

        expect(Atua::ImportReportCommand).not_to have_received(:call)
        expect(good_job_record(waiting)).to have_attributes(finished_at: nil, performed_at: nil)
        expect(good_job_record(waiting).scheduled_at).to be > Time.current
      end

      it 'keeps a single Atua session across tenants and reports' do
        mark_good_job_running(described_class.perform_later(other_tenant.id, 'customers', nil, nil))
        waiting = described_class.perform_later(tenant.id, 'manifests', start_date, end_date)

        GoodJob.perform_inline

        expect(Atua::ImportReportCommand).not_to have_received(:call)
        expect(good_job_record(waiting).finished_at).to be_nil
        expect(good_job_record(waiting).scheduled_at).to be > Time.current
      end
    end
  end
end
