require "test_helper"

class UserTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "envia o e-mail de confirmação em segundo plano ao se cadastrar" do
    assert_enqueued_emails 1 do
      User.create!(email: "novo@transjrbi.local", password: "senha-segura-123", password_confirmation: "senha-segura-123")
    end
  end

  test "usuário confirmado pode entrar" do
    assert users(:confirmado).active_for_authentication?
  end
end
