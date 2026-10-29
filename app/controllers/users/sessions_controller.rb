module Users
  class SessionsController < Devise::SessionsController
    REMEMBERED_EMAIL_COOKIE = :remembered_email

    def new
      super do |user|
        remembered_email = cookies.signed[REMEMBERED_EMAIL_COOKIE]
        next if remembered_email.blank? || user.email.present?

        user.email = remembered_email
        user.remember_me = true
      end
    end

    def create
      super do |user|
        remember_me(user)
        remember_email(user)
      end
    end

    private

    def remember_email(user)
      if ActiveModel::Type::Boolean.new.cast(sign_in_params[:remember_me])
        cookies.signed[REMEMBERED_EMAIL_COOKIE] = { value: user.email, expires: Devise.remember_for.from_now, httponly: true }
      else
        cookies.delete(REMEMBERED_EMAIL_COOKIE)
      end
    end
  end
end
