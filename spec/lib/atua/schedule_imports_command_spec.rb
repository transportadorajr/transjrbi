require 'rails_helper'

RSpec.describe Atua::ScheduleImportsCommand do
  let!(:enabled_tenant) { create(:tenant) }
  let!(:disabled_tenant) { create(:tenant) }
  let(:period) { { start_date: Date.new(2026, 10, 5), end_date: Date.new(2026, 10, 14) } }

  context 'with the flag on for one tenant', flipper: { atua_import: :enabled_tenant } do
    it 'enqueues each report only for the enabled tenant' do
      jobs = described_class.call(%i[manifests expenses], **period)

      expect(jobs.size).to eq(2)
      expect(Atua::ImportReportJob).to have_been_enqueued.with(enabled_tenant.id, 'manifests', *period.values)
      expect(Atua::ImportReportJob).to have_been_enqueued.with(enabled_tenant.id, 'expenses', *period.values)
      expect(Atua::ImportReportJob).not_to have_been_enqueued.with(disabled_tenant.id, any_args)
    end
  end

  context 'without the flag' do
    it 'enqueues nothing' do
      expect(described_class.call(%i[customers])).to eq([])
      expect(Atua::ImportReportJob).not_to have_been_enqueued
    end
  end
end
