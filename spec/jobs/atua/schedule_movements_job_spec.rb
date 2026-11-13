require 'rails_helper'

RSpec.describe Atua::ScheduleMovementsJob do
  let!(:enabled_tenant) { create(:tenant) }
  let!(:disabled_tenant) { create(:tenant) }

  around { |example| travel_to(Time.zone.local(2026, 10, 14, 8)) { example.run } }

  context 'with the flag on for one tenant', flipper: { atua_import: :enabled_tenant } do
    it 'enqueues the current day of movements and the last week of manifests only for the enabled tenant' do
      described_class.perform_now

      %w[transport_documents expenses toll_vouchers].each do |report_type|
        expect(Atua::ImportReportJob).to have_been_enqueued
          .with(enabled_tenant.id, report_type, Date.new(2026, 10, 14), Date.new(2026, 10, 14))
      end
      expect(Atua::ImportReportJob).to have_been_enqueued
        .with(enabled_tenant.id, 'manifests', Date.new(2026, 10, 8), Date.new(2026, 10, 14))
      expect(Atua::ImportReportJob).to have_been_enqueued.exactly(4).times
      expect(Atua::ImportReportJob).not_to have_been_enqueued.with(disabled_tenant.id, any_args)
    end

    it 'imports again the manifests issued days ago so a later closing reaches the app' do
      described_class.perform_now

      expect(Atua::ImportReportJob).to have_been_enqueued
        .with(enabled_tenant.id, 'manifests', Date.new(2026, 10, 8), Date.new(2026, 10, 14))
      expect(Atua::ImportReportJob).not_to have_been_enqueued
        .with(enabled_tenant.id, 'manifests', Date.new(2026, 10, 14), Date.new(2026, 10, 14))
    end

    it 'accepts another number of days' do
      described_class.perform_now(3)

      expect(Atua::ImportReportJob).to have_been_enqueued
        .with(enabled_tenant.id, 'transport_documents', Date.new(2026, 10, 12), Date.new(2026, 10, 14))
      expect(Atua::ImportReportJob).to have_been_enqueued
        .with(enabled_tenant.id, 'manifests', Date.new(2026, 10, 8), Date.new(2026, 10, 14))
    end

    it 'widens the manifests to a number of days longer than a week' do
      described_class.perform_now(10)

      expect(Atua::ImportReportJob).to have_been_enqueued
        .with(enabled_tenant.id, 'manifests', Date.new(2026, 10, 5), Date.new(2026, 10, 14))
    end
  end

  context 'with the flag on for everyone', flipper: :atua_import do
    it 'enqueues the movements of every tenant' do
      described_class.perform_now

      expect(Atua::ImportReportJob).to have_been_enqueued.exactly(8).times
      expect(Atua::ImportReportJob).to have_been_enqueued.with(disabled_tenant.id, 'expenses', any_args)
    end
  end

  context 'without the flag' do
    it 'enqueues nothing' do
      described_class.perform_now

      expect(Atua::ImportReportJob).not_to have_been_enqueued
    end
  end
end
