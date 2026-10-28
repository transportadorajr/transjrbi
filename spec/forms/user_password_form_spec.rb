require 'rails_helper'

RSpec.describe UserPasswordForm do
  let(:user) { create(:user, confirmed_at: nil) }

  describe 'validations' do
    it 'requires the password' do
      form = described_class.new(user:)

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to include('Senha não pode ficar em branco')
    end

    it 'rejects a confirmation that does not match the password' do
      form = described_class.new(user:, password: 'NovaSenha1!', password_confirmation: 'Outra123!')

      expect(form).not_to be_valid
      expect(form.errors[:password_confirmation]).to include('não é igual a Senha')
    end

    it 'rejects a password that is too short' do
      form = described_class.new(user:, password: '123', password_confirmation: '123')

      expect(form).not_to be_valid
      expect(form.errors[:password]).to be_present
    end

    it 'rejects a user that already confirmed the account' do
      form = described_class.new(user: create(:user), password: 'NovaSenha1!', password_confirmation: 'NovaSenha1!')

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to include('Este usuário já confirmou a conta.')
    end
  end

  describe '#save' do
    it 'confirms the account with the given password and discards the confirmation link' do
      form = described_class.new(user:, password: 'NovaSenha1!', password_confirmation: 'NovaSenha1!')

      expect(form.save).to be(true)

      user.reload
      expect(user.confirmed_at).to be_present
      expect(user.confirmation_token).to be_nil
      expect(user.valid_password?('NovaSenha1!')).to be(true)
    end

    it 'keeps the user pending when the form is invalid' do
      form = described_class.new(user:, password: 'NovaSenha1!', password_confirmation: 'Outra123!')

      expect(form.save).to be_falsey
      expect(user.reload.confirmed_at).to be_nil
    end
  end
end
