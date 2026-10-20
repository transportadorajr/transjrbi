require 'capybara/rails'
require 'capybara/cuprite'

Capybara.server = :puma, { Silent: true }
Capybara.javascript_driver = :cuprite
Capybara.default_max_wait_time = 10
Capybara.save_path = 'tmp'
Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [1920, 1080], headless: ENV['INSPECTOR'].blank?, timeout: 10,
                                     process_timeout: 60, browser_options: { 'no-sandbox': nil },
                                     url_blacklist: %w[https://fonts.googleapis.com https://fonts.gstatic.com])
end

module CapybaraHelpers
  def use_mobile_screen(width: 390, height: 844)
    page.driver.resize(width, height)
  end
end

module AdminHelpers
  def sign_in_admin(admin_user, password: 'Senha123!')
    visit admin_login_path
    fill_in 'E-mail', with: admin_user.email
    fill_in 'Senha', with: password
    click_on 'Entrar'
  end
end

RSpec.configure do |config|
  config.include CapybaraHelpers, type: :feature
  config.include AdminHelpers, :admin, type: :feature

  config.around(:each, :admin, type: :feature) do |example|
    original_app_host = Capybara.app_host
    original_always_include_port = Capybara.always_include_port
    Capybara.app_host = "http://#{Rails.application.config.x.admin_host}"
    Capybara.always_include_port = true

    example.run
  ensure
    Capybara.app_host = original_app_host
    Capybara.always_include_port = original_always_include_port
  end
end
