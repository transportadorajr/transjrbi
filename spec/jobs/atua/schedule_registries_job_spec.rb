require 'rails_helper'

RSpec.describe Atua::ScheduleRegistriesJob do
  let!(:enabled_tenant) { create(:tenant) }
  let!(:disabled_tenant) { create(:tenant) }

  context 'with the flag on for one tenant', flipper: { atua_import: :enabled_tenant } do
    it 'enqueues the customers and vehicles only for the enabled tenant' do
      described_class.perform_now

      expect(Atua::ImportReportJob).to have_been_enqueued.with(enabled_tenant.id, 'customers', nil, nil)
      expect(Atua::ImportReportJob).to have_been_enqueued.with(enabled_tenant.id, 'vehicles', nil, nil)
      expect(Atua::ImportReportJob).to have_been_enqueued.exactly(2).times
    end
  end

  context 'without the flag' do
    it 'enqueues nothing' do
      described_class.perform_now

      expect(Atua::ImportReportJob).not_to have_been_enqueued
    end
  end
end
