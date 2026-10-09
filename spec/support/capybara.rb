require 'capybara/rails'
require 'capybara/cuprite'

Capybara.server = :puma, { Silent: true }
Capybara.javascript_driver = :cuprite
Capybara.default_max_wait_time = 10
Capybara.save_path = 'tmp'
Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [1920, 1080], headless: ENV['INSPECTOR'].blank?, timeout: 10,
                                     process_timeout: 30, browser_options: { 'no-sandbox': nil })
end

module CapybaraHelpers
  def use_mobile_screen(width: 390, height: 844)
    page.driver.resize(width, height)
  end
end

RSpec.configure do |config|
  config.include CapybaraHelpers, type: :feature
end
