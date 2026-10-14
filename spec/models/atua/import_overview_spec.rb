require 'rails_helper'

RSpec.describe Atua::ImportOverview do
  let(:now) { Time.zone.local(2026, 10, 14, 12) }

  around { |example| travel_to(now) { example.run } }

  def succeed(tenant, report_type, finished_at)
    create(:atua_import, tenant:, report_type:, status_type: 'succeeded', finished_at:, start_date: nil, end_date: nil)
  end

  def report_statuses(status)
    status.reports.to_h { |report| [report.report_type, [report.last_succeeded_at, report.late?]] }
  end

  context 'with an enabled and a disabled tenant', flipper: { atua_import: :enabled_tenant } do
    let!(:enabled_tenant) { create(:tenant, trade_name: 'TransJR') }
    let!(:disabled_tenant) { create(:tenant, trade_name: 'Outra') }

    before do
      succeed(enabled_tenant, 'transport_documents', now - 2.hours)
      succeed(enabled_tenant, 'transport_documents', now - 5.hours)
      succeed(enabled_tenant, 'manifests', now - 4.hours)
      succeed(enabled_tenant, 'customers', now - 1.day)
      succeed(enabled_tenant, 'vehicles', now - 3.days)
      create(:atua_import, tenant: enabled_tenant, report_type: 'expenses', status_type: 'failed', finished_at: now - 1.hour)
      succeed(disabled_tenant, 'customers', now - 10.days)
    end

    it 'returns the last success of each report with the late ones flagged' do
      enabled, disabled = described_class.new(Tenant.order(:id)).statuses

      expect(enabled).to have_attributes(tenant: enabled_tenant, enabled?: true)
      expect(report_statuses(enabled)).to eq(
        transport_documents: [now - 2.hours, false],
        manifests: [now - 4.hours, true],
        expenses: [nil, true],
        customers: [now - 1.day, false],
        vehicles: [now - 3.days, true],
      )
      expect(disabled).to have_attributes(tenant: disabled_tenant, enabled?: false)
      expect(report_statuses(disabled)).to eq(
        transport_documents: [nil, false], manifests: [nil, false], expenses: [nil, false], customers: [now - 10.days, false],
        vehicles: [nil, false]
      )
    end
  end
end
