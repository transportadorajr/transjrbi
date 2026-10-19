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

  describe 'device verification' do
    let(:app) { Rack::MockSession.new(described_class, 'localhost') }
    let(:browser) { Rack::Test::Session.new(app) }
    let(:credentials) { { f_ds_apelido: 'transjr', f_ds_senha: 'secret' } }

    around { |example| ClimateControl.modify(ATUA_MOCK_DEVICE_VERIFICATION: 'true', ATUA_MOCK_DEVICE_CODE: 'XYZ789') { example.run } }

    before do
      described_class.set(:trusted_devices, Set.new)
      described_class.set(:pending_codes, {})
      described_class.set(:verified_sessions, {})
    end

    it 'asks for the e-mail code from an unknown device' do
      browser.post '/adm/login.php', credentials

      expect(browser.last_response.body).to include("validarAutenticacaoUsuario('2')", "cdPessoa: '9430'")
    end

    it 'trusts the device after the code is confirmed' do
      browser.post '/adm/login.php', credentials
      browser.get '/adm/lib/jaguar/AjaxIframe.php', c: 'UsuarioAutenticacao', a: 'enviarCodigoValidacao',
                                                    p: { dsDadoAutenticacao: 'integracao@transjr.test' }
      browser.get '/adm/lib/jaguar/AjaxIframe.php', c: 'UsuarioAutenticacaoLogin', a: 'validarCodigo', p: { nrVerificacao: 'XYZ789' }
      device_hash = JSON.parse(browser.last_response.body).fetch('dsHashAplicativo')

      fresh = Rack::Test::Session.new(Rack::MockSession.new(described_class, 'localhost'))
      fresh.set_cookie("c_ds_dispositivo_mock_9430=#{device_hash}")
      fresh.post '/adm/login.php', credentials.merge(f_id_hash_aplicativo: device_hash)

      expect(fresh.last_response.body).to include('signed in')
    end

    it 'refuses a wrong code' do
      browser.post '/adm/login.php', credentials
      browser.get '/adm/lib/jaguar/AjaxIframe.php', c: 'UsuarioAutenticacao', a: 'enviarCodigoValidacao',
                                                    p: { dsDadoAutenticacao: 'integracao@transjr.test' }
      browser.get '/adm/lib/jaguar/AjaxIframe.php', c: 'UsuarioAutenticacaoLogin', a: 'validarCodigo', p: { nrVerificacao: 'WRONG1' }

      expect(JSON.parse(browser.last_response.body)).to eq('erro' => 'Código inválido.')
    end
  end
end
