require 'test_helper'

class PagesControllerTest < ActionDispatch::IntegrationTest
  test 'página inicial responde' do
    get root_url
    assert_response :success
  end

  test 'dashboard do GoodJob exige login' do
    get '/good_job'
    assert_redirected_to new_user_session_url
  end
end
