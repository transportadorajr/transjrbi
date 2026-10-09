class UserMailer < Devise::Mailer
  def confirmation_instructions(record, token, opts = {})
    return super if record.pending_reconfirmation?

    @token = token
    devise_mail(record, :account_confirmation_instructions, opts)
  end
end
