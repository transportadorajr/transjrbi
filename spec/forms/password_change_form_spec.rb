require 'rails_helper'

RSpec.describe PasswordChangeForm do
  let(:user) { create(:user, password_change_required: true) }

  describe 'validations' do
    it 'requires the password' do
      form = described_class.new(user:)

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to include('Nova senha não pode ficar em branco')
    end

    it 'rejects a confirmation that does not match the password' do
      form = described_class.new(user:, password: 'NovaSenha1!', password_confirmation: 'Outra123!')

      expect(form).not_to be_valid
      expect(form.errors[:password_confirmation]).to include('não é igual a Nova senha')
    end

    it 'rejects a password that is too short' do
      form = described_class.new(user:, password: '123', password_confirmation: '123')

      expect(form).not_to be_valid
      expect(form.errors[:password]).to be_present
    end

    it 'rejects the current password' do
      form = described_class.new(user:, password: 'Senha123!', password_confirmation: 'Senha123!')

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to include('Nova senha deve ser diferente da senha atual')
    end
  end

  describe '#save' do
    it 'changes the password and clears the required password change' do
      form = described_class.new(user:, password: 'NovaSenha1!', password_confirmation: 'NovaSenha1!')

      expect(form.save).to be(true)

      user.reload
      expect(user.valid_password?('NovaSenha1!')).to be(true)
      expect(user.password_change_required?).to be(false)
    end

    it 'keeps the password and the required change when the form is invalid' do
      form = described_class.new(user:, password: 'NovaSenha1!', password_confirmation: 'Outra123!')

      expect(form.save).to be_falsey

      user.reload
      expect(user.valid_password?('Senha123!')).to be(true)
      expect(user.password_change_required?).to be(true)
    end
  end
end
