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

  set :port, ENV.fetch('ATUA_MOCK_PORT', 4567).to_i
  set :bind, '0.0.0.0'
  set :sessions_store, Set.new

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

    def login_page
      session_id
      content_type 'text/html'
      <<~HTML
        <html><body><form method="post" action="login.php">
          <input type="hidden" name="f_origem" value="index.php">
          <input type="text" name="f_ds_apelido"><input type="password" name="f_ds_senha">
          <input type="submit" value="Entrar">
        </form></body></html>
      HTML
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

  post '/adm/login.php' do
    return login_page unless valid_credentials?

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
