module Admin
  class LoginForm < BaseForm
    attr_reader :user

    attribute :email, :string
    attribute :password, :string

    validates :email, :password, presence: true

    def submit
      @user = Admin::User.find_by(email: email.to_s.strip.downcase)

      return if @user&.authenticate(password)

      errors.add(:base, :invalid_login)
      @user = nil
    end
  end
end
