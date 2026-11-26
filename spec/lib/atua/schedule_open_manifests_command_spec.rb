require 'rails_helper'

RSpec.describe Atua::ScheduleOpenManifestsCommand do
  let!(:enabled_tenant) { create(:tenant) }
  let!(:disabled_tenant) { create(:tenant) }

  around { |example| travel_to(Time.zone.local(2026, 11, 26, 5, 45)) { example.run } }

  context 'with a manifest left open before the last week of manifests', flipper: { atua_import: :enabled_tenant } do
    before do
      create(:atua_manifest, tenant: enabled_tenant, issued_on: Date.new(2026, 11, 4), status: 'Normal')
      create(:atua_manifest, tenant: enabled_tenant, issued_on: Date.new(2026, 10, 30), status: 'Encerrado')
      create(:atua_manifest, tenant: enabled_tenant, issued_on: Date.new(2026, 11, 24), status: 'Normal')
      create(:atua_manifest, tenant: disabled_tenant, issued_on: Date.new(2026, 11, 2), status: 'Normal')
    end

    it 'imports again the manifests from the oldest one still open up to the day before the last week' do
      jobs = described_class.call

      expect(jobs.size).to eq(1)
      expect(Atua::ImportReportJob).to have_been_enqueued
        .with(enabled_tenant.id, 'manifests', Date.new(2026, 11, 4), Date.new(2026, 11, 19))
      expect(Atua::ImportReportJob).not_to have_been_enqueued.with(disabled_tenant.id, any_args)
    end
  end

  context 'with only closed, canceled, removed or recent manifests', flipper: { atua_import: :enabled_tenant } do
    before do
      create(:atua_manifest, tenant: enabled_tenant, issued_on: Date.new(2026, 11, 4), status: 'Encerrado')
      create(:atua_manifest, tenant: enabled_tenant, issued_on: Date.new(2026, 11, 5), status: 'Cancelado')
      create(:atua_manifest, tenant: enabled_tenant, issued_on: Date.new(2026, 11, 6), status: 'Normal', removed_from_atua_at: Time.current)
      create(:atua_manifest, tenant: enabled_tenant, issued_on: Date.new(2026, 11, 20), status: 'Normal')
    end

    it 'enqueues nothing' do
      expect(described_class.call).to eq([])
      expect(Atua::ImportReportJob).not_to have_been_enqueued
    end
  end

  context 'with a manifest open for longer than the lookback', flipper: { atua_import: :enabled_tenant } do
    before do
      create(:atua_manifest, tenant: enabled_tenant, issued_on: Date.new(2026, 9, 1), status: 'Normal')
      create(:atua_manifest, tenant: enabled_tenant, issued_on: Date.new(2026, 10, 15), status: 'Normal')
    end

    it 'starts at the oldest open manifest inside the lookback' do
      described_class.call

      expect(Atua::ImportReportJob).to have_been_enqueued.exactly(1).times
      expect(Atua::ImportReportJob).to have_been_enqueued
        .with(enabled_tenant.id, 'manifests', Date.new(2026, 10, 15), Date.new(2026, 11, 19))
    end
  end

  context 'without the flag' do
    before { create(:atua_manifest, tenant: enabled_tenant, issued_on: Date.new(2026, 11, 4), status: 'Normal') }

    it 'enqueues nothing' do
      expect(described_class.call).to eq([])
      expect(Atua::ImportReportJob).not_to have_been_enqueued
    end
  end
end
