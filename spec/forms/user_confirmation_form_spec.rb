require 'rails_helper'

RSpec.describe UserConfirmationForm do
  let!(:user) { create(:user, email: 'ana@transjrbi.com.br', confirmed_at: nil) }

  describe 'validations' do
    it 'requires the password' do
      form = described_class.new(confirmation_token: user.confirmation_token)

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to contain_exactly('Senha não pode ficar em branco')
    end

    it 'requires the password confirmation to match' do
      form = described_class.new(confirmation_token: user.confirmation_token, password: 'Senha123!',
                                 password_confirmation: 'Outra123!')

      expect(form).not_to be_valid
      expect(form.errors[:password_confirmation]).to include('não é igual a Senha')
    end

    it 'rejects a password shorter than the minimum length' do
      form = described_class.new(confirmation_token: user.confirmation_token, password: 'abc', password_confirmation: 'abc')

      expect(form).not_to be_valid
      expect(form.errors[:password]).to include('é muito curto (mínimo: 8 caracteres)')
    end

    it 'rejects an unknown token' do
      form = described_class.new(confirmation_token: 'unknown', password: 'Senha123!', password_confirmation: 'Senha123!')

      expect(form).not_to be_valid
      expect(form.errors[:base]).to include('O link de confirmação é inválido ou expirou. Solicite um novo link.')
    end

    it 'rejects an expired token' do
      form = described_class.new(confirmation_token: user.confirmation_token, password: 'Senha123!',
                                 password_confirmation: 'Senha123!')

      travel_to(4.days.from_now) do
        expect(form).not_to be_valid
        expect(form.errors[:base]).to include('O link de confirmação é inválido ou expirou. Solicite um novo link.')
      end
    end

    it 'rejects a token of an account already confirmed' do
      token = user.confirmation_token
      user.confirm
      form = described_class.new(confirmation_token: token, password: 'Senha123!',
                                 password_confirmation: 'Senha123!')

      expect(form).not_to be_valid
      expect(form.errors[:base]).to include('O link de confirmação é inválido ou expirou. Solicite um novo link.')
    end
  end

  describe '#save' do
    it 'confirms the account and defines the password' do
      form = described_class.new(confirmation_token: user.confirmation_token, password: 'NovaSenha1!',
                                 password_confirmation: 'NovaSenha1!')

      expect(form.save).to be(true)

      user.reload
      expect(user.confirmed_at).to be_present
      expect(user.confirmation_token).to be_nil
      expect(user.valid_password?('NovaSenha1!')).to be(true)
    end

    it 'keeps the account unconfirmed when the form is invalid' do
      form = described_class.new(confirmation_token: user.confirmation_token, password: 'NovaSenha1!',
                                 password_confirmation: 'Diferente1!')

      expect(form.save).to be_falsey

      user.reload
      expect(user.confirmed_at).to be_nil
      expect(user.confirmation_token).to be_present
      expect(user.valid_password?('NovaSenha1!')).to be(false)
    end
  end

  describe '.model_name' do
    it 'uses the user confirmation param key' do
      expect(described_class.model_name.param_key).to eq('user_confirmation')
    end
  end
end
