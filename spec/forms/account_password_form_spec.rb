require 'rails_helper'

RSpec.describe AccountPasswordForm do
  let(:user) { create(:user) }

  describe 'validations' do
    it 'requires the current password and the new password' do
      form = described_class.new(user:)

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to include('Senha atual não pode ficar em branco',
                                                   'Nova senha não pode ficar em branco')
    end

    it 'rejects a wrong current password' do
      form = described_class.new(user:, current_password: 'Errada123!', password: 'NovaSenha1!',
                                 password_confirmation: 'NovaSenha1!')

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to include('Senha atual está incorreta')
    end

    it 'rejects a confirmation that does not match the password' do
      form = described_class.new(user:, current_password: 'Senha123!', password: 'NovaSenha1!',
                                 password_confirmation: 'Outra123!')

      expect(form).not_to be_valid
      expect(form.errors[:password_confirmation]).to include('não é igual a Nova senha')
    end

    it 'rejects a password that is too short' do
      form = described_class.new(user:, current_password: 'Senha123!', password: '123', password_confirmation: '123')

      expect(form).not_to be_valid
      expect(form.errors[:password]).to be_present
    end

    it 'rejects a new password equal to the current one' do
      form = described_class.new(user:, current_password: 'Senha123!', password: 'Senha123!',
                                 password_confirmation: 'Senha123!')

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to include('Nova senha deve ser diferente da senha atual')
    end
  end

  describe '#save' do
    it 'changes the password of the user' do
      form = described_class.new(user:, current_password: 'Senha123!', password: 'NovaSenha1!',
                                 password_confirmation: 'NovaSenha1!')

      expect(form.save).to be(true)
      expect(user.reload.valid_password?('NovaSenha1!')).to be(true)
    end

    it 'keeps the password when the form is invalid' do
      form = described_class.new(user:, current_password: 'Errada123!', password: 'NovaSenha1!',
                                 password_confirmation: 'NovaSenha1!')

      expect(form.save).to be_falsey
      expect(user.reload.valid_password?('Senha123!')).to be(true)
    end
  end
end
