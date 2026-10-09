class UserMailerPreview < ActionMailer::Preview
  def confirmation_instructions
    user = User.new(name: 'Ana Paula', email: 'ana@transjrbi.com.br')

    UserMailer.confirmation_instructions(user, 'preview-token')
  end
end
