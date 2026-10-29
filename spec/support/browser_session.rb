module BrowserSession
  def close_browser
    page.driver.browser.current_session.cookie_jar.delete(Rails.application.config.session_options[:key])
  end
end

RSpec.configure do |config|
  config.include BrowserSession, type: :feature
end
