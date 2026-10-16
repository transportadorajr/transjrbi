require 'rails_helper'
require Rails.root.join('mock/atua_server')

RSpec.describe AtuaServer do
  subject(:server) { described_class.new! }

  let(:local_reports) { Dir.mktmpdir }

  before { stub_const('AtuaServer::LOCAL_REPORTS', local_reports) }

  after { FileUtils.remove_entry(local_reports) }

  it 'serves the committed fixture when there is no local report' do
    expect(server.report_file('transport_documents')).to eq(Rails.root.join('spec/fixtures/files/atua/transport_documents.xls').to_s)
  end

  it 'serves the local report in place of the fixture' do
    local = File.join(local_reports, 'transport_documents.xls')
    FileUtils.touch(local)

    expect(server.report_file('transport_documents')).to eq(local)
    expect(server.report_file('manifests')).to eq(Rails.root.join('spec/fixtures/files/atua/manifests.xls').to_s)
  end
end
