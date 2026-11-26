require 'rails_helper'

RSpec.describe Atua::ScheduleOpenManifestsJob do
  let!(:tenant) { create(:tenant) }

  around { |example| travel_to(Time.zone.local(2026, 11, 26, 5, 45)) { example.run } }

  context 'with a manifest issued two weeks ago still open in the app', flipper: :atua_import do
    before { create(:atua_manifest, tenant:, issued_on: Date.new(2026, 11, 11), status: 'Normal') }

    it 'imports it again so its later closing reaches the app' do
      described_class.perform_now

      expect(Atua::ImportReportJob).to have_been_enqueued
        .with(tenant.id, 'manifests', Date.new(2026, 11, 11), Date.new(2026, 11, 19))
    end
  end

  it 'is scheduled every day at 5h45' do
    expect(GoodJob.configuration.cron.fetch(:atua_open_manifests).slice(:cron, :class))
      .to eq(cron: '45 5 * * * America/Sao_Paulo', class: 'Atua::ScheduleOpenManifestsJob')
  end
end
