require 'rails_helper'

RSpec.describe Atua::InitialLoadCommand do
  let!(:tenant) { create(:tenant) }
  let(:now) { Time.zone.local(2026, 10, 14, 10) }

  around { |example| travel_to(now) { example.run } }

  def enqueued_imports
    enqueued_jobs.select { |job| job['job_class'] == 'Atua::ImportReportJob' }.map do |job|
      tenant_id, report_type, start_date, end_date = ActiveJob::Arguments.deserialize(job['arguments'])
      [tenant_id, report_type, start_date, end_date, job['scheduled_at'] && Time.zone.parse(job['scheduled_at'])]
    end
  end

  it 'enqueues the registries first and then the movements month by month until today' do
    described_class.call(tenant, Date.new(2026, 8, 15))

    expect(enqueued_imports).to eq(
      [
        [tenant.id, 'customers', nil, nil, nil],
        [tenant.id, 'vehicles', nil, nil, nil],
        [tenant.id, 'transport_documents', Date.new(2026, 8, 15), Date.new(2026, 8, 31), now + 10.minutes],
        [tenant.id, 'manifests', Date.new(2026, 8, 15), Date.new(2026, 8, 31), now + 10.minutes],
        [tenant.id, 'expenses', Date.new(2026, 8, 15), Date.new(2026, 8, 31), now + 10.minutes],
        [tenant.id, 'transport_documents', Date.new(2026, 9, 1), Date.new(2026, 9, 30), now + 20.minutes],
        [tenant.id, 'manifests', Date.new(2026, 9, 1), Date.new(2026, 9, 30), now + 20.minutes],
        [tenant.id, 'expenses', Date.new(2026, 9, 1), Date.new(2026, 9, 30), now + 20.minutes],
        [tenant.id, 'transport_documents', Date.new(2026, 10, 1), Date.new(2026, 10, 14), now + 30.minutes],
        [tenant.id, 'manifests', Date.new(2026, 10, 1), Date.new(2026, 10, 14), now + 30.minutes],
        [tenant.id, 'expenses', Date.new(2026, 10, 1), Date.new(2026, 10, 14), now + 30.minutes],
      ],
    )
  end

  context 'when some months were already imported' do
    before do
      %w[transport_documents manifests expenses].each do |report_type|
        create(:atua_import, tenant:, report_type:, status_type: 'succeeded', start_date: Date.new(2026, 8, 15), end_date: Date.new(2026, 8, 31))
      end
      create(:atua_import, tenant:, report_type: 'manifests', status_type: 'succeeded', start_date: Date.new(2026, 9, 1), end_date: Date.new(2026, 9, 30))
      create(:atua_import, tenant:, report_type: 'expenses', status_type: 'failed', start_date: Date.new(2026, 9, 1), end_date: Date.new(2026, 9, 30))
    end

    it 'skips only the reports already imported with success' do
      described_class.call(tenant, Date.new(2026, 8, 15))

      expect(enqueued_imports.pluck(1..3)).to eq(
        [
          ['customers', nil, nil],
          ['vehicles', nil, nil],
          ['transport_documents', Date.new(2026, 9, 1), Date.new(2026, 9, 30)],
          ['expenses', Date.new(2026, 9, 1), Date.new(2026, 9, 30)],
          ['transport_documents', Date.new(2026, 10, 1), Date.new(2026, 10, 14)],
          ['manifests', Date.new(2026, 10, 1), Date.new(2026, 10, 14)],
          ['expenses', Date.new(2026, 10, 1), Date.new(2026, 10, 14)],
        ],
      )
      expect(enqueued_imports.map(&:last).uniq).to eq([nil, now + 10.minutes, now + 20.minutes])
    end
  end
end
