require 'rails_helper'

RSpec.describe Admin::User do
  it 'normalizes the e-mail' do
    expect(create(:admin_user, email: '  Marina@TransJRBI.com.br ').email).to eq('marina@transjrbi.com.br')
  end

  it 'requires name and e-mail' do
    admin_user = described_class.new(password: 'Senha123!')

    expect(admin_user).not_to be_valid
    expect(admin_user.errors.attribute_names).to contain_exactly(:name, :email)
  end

  context 'with an existing admin user' do
    let!(:admin_user) { create(:admin_user, email: 'marina@transjrbi.com.br') }

    it 'rejects a repeated e-mail' do
      expect(build(:admin_user, email: 'MARINA@transjrbi.com.br')).not_to be_valid
    end

    it 'authenticates only with the right password' do
      expect(admin_user.authenticate('Senha123!')).to eq(admin_user)
      expect(admin_user.authenticate('errada')).to be(false)
    end

    it 'refuses a corrupted password digest' do
      admin_user.update_column(:password_digest, 'invalid')

      expect(admin_user.reload.authenticate('Senha123!')).to be(false)
    end
  end
end
