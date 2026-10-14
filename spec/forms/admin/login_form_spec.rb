require 'rails_helper'

RSpec.describe Admin::LoginForm do
  let!(:admin_user) { create(:admin_user, email: 'marina@transjrbi.com.br') }

  it 'finds the admin user with the right password' do
    form = described_class.new(email: ' Marina@TransJRBI.com.br ', password: 'Senha123!')

    expect(form.save).to be(true)
    expect(form.user).to eq(admin_user)
  end

  it 'refuses a wrong password' do
    form = described_class.new(email: 'marina@transjrbi.com.br', password: 'errada')

    expect(form.save).to be(false)
    expect(form.user).to be_nil
    expect(form.errors.full_messages).to eq(['E-mail ou senha inválidos.'])
  end

  it 'requires e-mail and password' do
    form = described_class.new

    expect(form.save).to be_falsey
    expect(form.errors.full_messages).to eq(['E-mail não pode ficar em branco', 'Senha não pode ficar em branco'])
  end
end
