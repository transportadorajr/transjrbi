require 'rails_helper'

describe 'Health check' do
  let(:drain_file) { Pathname(Dir.mktmpdir).join('drain') }

  before { stub_const('HealthController::DRAIN_FILE', drain_file) }

  after { FileUtils.rm_rf(drain_file.dirname) }

  context 'when the container is serving traffic' do
    scenario 'reports the application as up' do
      visit rails_health_check_path

      expect(page.status_code).to eq(200)
    end
  end

  context 'when the container is draining before a deploy stops it' do
    before { FileUtils.touch(drain_file) }

    scenario 'reports the application as unavailable so the proxy stops routing to it' do
      visit rails_health_check_path

      expect(page.status_code).to eq(503)
    end
  end
end
