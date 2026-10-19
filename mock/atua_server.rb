require 'securerandom'
require 'yaml'
require 'sinatra/base'

class AtuaServer < Sinatra::Base
  ROOT = File.expand_path('..', __dir__)
  FIXTURES = File.join(ROOT, 'spec/fixtures/files/atua')
  LOCAL_REPORTS = File.join(ROOT, 'tmp/atua/mock')
  REPORTS = Dir[File.join(ROOT, 'config/atua/reports/*.yml')].to_h do |path|
    [YAML.load_file(path).fetch('endpoint'), File.basename(path, '.yml')]
  end.freeze
  SESSION_COOKIE = 'PHPSESSID'.freeze
  XLS_CONTENT_TYPE = 'application/vnd.ms-excel'.freeze
  DEVICE_COOKIE = 'c_ds_dispositivo_mock_9430'.freeze
  PERSON_ID = '9430'.freeze
  EMAIL = 'integracao@transjr.test'.freeze
  MASKED_EMAIL = 'int*******@t******.test'.freeze

  set :port, ENV.fetch('ATUA_MOCK_PORT', 4567).to_i
  set :bind, '0.0.0.0'
  set :sessions_store, Set.new
  set :trusted_devices, Set.new
  set :pending_codes, {}
  set :verified_sessions, {}

  helpers do
    def session_id
      request.cookies[SESSION_COOKIE] || SecureRandom.hex(16).tap { |id| response.set_cookie(SESSION_COOKIE, value: id, path: '/') }
    end

    def logged_in?
      settings.sessions_store.include?(request.cookies[SESSION_COOKIE])
    end

    def valid_credentials?
      username = ENV.fetch('ATUA_MOCK_USERNAME', nil)
      password = ENV.fetch('ATUA_MOCK_PASSWORD', nil)
      return params[:f_ds_apelido].to_s != '' && params[:f_ds_senha].to_s != '' if username.nil? || password.nil?

      params[:f_ds_apelido] == username && params[:f_ds_senha] == password
    end

    def login_page(verification: false)
      session_id
      content_type 'text/html'
      <<~HTML
        <html><body>
        #{verification_script if verification}
        <form method="post" action="login.php" id="form_login">
          <input type="hidden" name="f_origem" value="index.php">
          <input type="hidden" name="f_id_hash_aplicativo" value="">
          <input type="text" name="f_ds_apelido"><input type="password" name="f_ds_senha">
          <input type="submit" name="submete051050" value="Acessar">
        </form></body></html>
      HTML
    end

    def verification_script
      <<~HTML
        <script>
        var dsEmail            = '#{EMAIL}';
        var dsEmailProtegido   = '#{MASKED_EMAIL}';
        function enviarCodigo(idTipoModal) { return {cdPessoa: '#{PERSON_ID}', idTipoModal: idTipoModal}; }
        $(document).ready(function() { validarAutenticacaoUsuario('2'); });
        </script>
      HTML
    end

    def device_verification?
      ENV['ATUA_MOCK_DEVICE_VERIFICATION'].to_s == 'true'
    end

    def device_code
      ENV.fetch('ATUA_MOCK_DEVICE_CODE', 'ABC123')
    end

    def trusted_device?
      hash = params[:f_id_hash_aplicativo].to_s
      hash != '' && settings.trusted_devices.include?(hash) && request.cookies[DEVICE_COOKIE] == hash
    end

    def verified_device?
      settings.verified_sessions[request.cookies[SESSION_COOKIE]] == params[:f_id_hash_aplicativo].to_s
    end

    def ajax(klass, action)
      content_type 'application/json'
      ajax_params = params[:p] || {}

      case [klass, action]
      when %w[UsuarioAutenticacao enviarCodigoValidacao]
        return { erro: 'E-mail inválido.' }.to_json unless ajax_params[:dsDadoAutenticacao] == EMAIL

        settings.pending_codes[request.cookies[SESSION_COOKIE]] = device_code
        { status: 'OK' }.to_json
      when %w[UsuarioAutenticacaoLogin validarCodigo]
        return { erro: 'Código inválido.' }.to_json unless settings.pending_codes[request.cookies[SESSION_COOKIE]] == ajax_params[:nrVerificacao]

        hash = SecureRandom.hex(32)
        settings.trusted_devices << hash
        settings.verified_sessions[request.cookies[SESSION_COOKIE]] = hash
        response.set_cookie(DEVICE_COOKIE, value: hash, path: '/', httponly: true)
        { dsHashAplicativo: hash }.to_json
      else
        halt 404
      end
    end

    def report_type
      REPORTS.fetch(params[:endpoint]) { halt 404 }
    end

    def report_file(type)
      local = File.join(LOCAL_REPORTS, "#{type}.xls")
      File.exist?(local) ? local : File.join(FIXTURES, "#{type}.xls")
    end
  end

  get('/adm/login.php') { login_page }

  get('/adm/lib/jaguar/AjaxIframe.php') { ajax(params[:c], params[:a]) }

  post '/adm/login.php' do
    return login_page unless valid_credentials?
    return login_page(verification: true) if device_verification? && !trusted_device? && !verified_device?

    settings.sessions_store << session_id
    content_type 'text/html'
    '<html><body>Atua mock: signed in.</body></html>'
  end

  get '/adm/:endpoint' do
    report_type
    return login_page unless logged_in?

    content_type 'text/html'
    %(<html><body><form method="post"><input type="submit" name="submete#{rand(100_000..999_999)}" value="Gerar"></form></body></html>)
  end

  post '/adm/:endpoint' do
    type = report_type
    return login_page unless logged_in?

    sleep(ENV.fetch('ATUA_MOCK_DELAY', 0).to_f)
    send_file report_file(type), type: XLS_CONTENT_TYPE, disposition: :attachment, filename: "#{type}_mock.xls"
  end

  run! if app_file == $PROGRAM_NAME
end
