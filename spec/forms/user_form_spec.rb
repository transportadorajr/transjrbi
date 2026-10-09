require 'rails_helper'

RSpec.describe UserForm do
  let(:tenant) { create(:tenant) }
  let!(:editor) { create(:user, tenant:, user_type: :admin) }

  describe 'validations' do
    it 'requires name, email and user type' do
      form = described_class.new(editor:)

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to contain_exactly(
        'Nome não pode ficar em branco',
        'E-mail não pode ficar em branco',
        'Perfil não pode ficar em branco',
      )
    end

    it 'rejects an invalid e-mail' do
      form = described_class.new(editor:, name: 'Ana', email: 'ana@', user_type: 'operator')

      expect(form).not_to be_valid
      expect(form.errors[:email]).to include('não é válido')
    end

    it 'rejects an e-mail already in use, ignoring case' do
      create(:user, email: 'ana@transjrbi.com.br')
      form = described_class.new(editor:, name: 'Ana', email: ' ANA@transjrbi.com.br ', user_type: 'operator')

      expect(form).not_to be_valid
      expect(form.errors[:email]).to include('já está em uso')
    end

    it 'rejects the owner type on a new user' do
      form = described_class.new(editor:, name: 'Ana', email: 'ana@transjrbi.com.br', user_type: 'owner')

      expect(form).not_to be_valid
      expect(form.errors[:user_type]).to include('não está incluído na lista')
    end

    it 'rejects a phone without 10 or 11 digits' do
      form = described_class.new(editor:, name: 'Ana', email: 'ana@transjrbi.com.br', user_type: 'operator', phone: '1234')

      expect(form).not_to be_valid
      expect(form.errors[:phone]).to include('não é válido')
    end

    it 'accepts a formatted mobile phone' do
      form = described_class.new(editor:, name: 'Ana', email: 'ana@transjrbi.com.br', user_type: 'operator', phone: '(31) 99876-5432')

      expect(form).to be_valid
    end
  end

  describe '#save on a new user' do
    let(:form) do
      described_class.new(editor:, name: ' Ana  Paula ', email: 'Ana@TransJRBI.com.br', phone: '(31) 99876-5432', user_type: 'admin')
    end

    it 'creates an activated user waiting for confirmation in the editor tenant' do
      expect { form.save }.to change(User, :count).by(1)

      user = User.last
      expect(user.tenant).to eq(tenant)
      expect(user.name).to eq('Ana Paula')
      expect(user.email).to eq('ana@transjrbi.com.br')
      expect(user.phone).to eq('(31) 99876-5432')
      expect(user.user_type).to eq('admin')
      expect(user.activated_at).to be_present
      expect(user.confirmed_at).to be_nil
      expect(user.confirmation_token).to be_present
    end

    it 'sends the account confirmation e-mail', :inline_jobs do
      expect { form.save }.to change { ActionMailer::Base.deliveries.count }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq(['ana@transjrbi.com.br'])
      expect(mail.subject).to eq('Confirme sua conta no TransJRBI')
    end
  end

  describe '#save on an existing user' do
    let(:user) { create(:user, tenant:, name: 'Ana', email: 'ana@transjrbi.com.br', user_type: :operator) }

    it 'updates name, phone and user type but keeps the e-mail' do
      form = described_class.for_user(user, editor:)
      form.assign_attributes(name: 'Ana Paula', phone: '3133334444', user_type: 'admin', email: 'outro@transjrbi.com.br')

      expect(form.save).to be(true)

      user.reload
      expect(user.name).to eq('Ana Paula')
      expect(user.phone).to eq('3133334444')
      expect(user.user_type).to eq('admin')
      expect(user.email).to eq('ana@transjrbi.com.br')
    end

    it 'does not send any e-mail' do
      form = described_class.for_user(user, editor:)
      form.assign_attributes(name: 'Ana Paula')

      expect { form.save }.not_to change(enqueued_jobs, :size)
    end

    it 'keeps the type of an owner' do
      owner = create(:user, tenant:, user_type: :owner)
      form = described_class.for_user(owner, editor:)
      form.assign_attributes(user_type: 'operator')

      expect(form.save).to be(true)
      expect(owner.reload.user_type).to eq('owner')
    end

    it 'keeps the type when an operator edits its own account' do
      form = described_class.for_user(user, editor: user)
      form.assign_attributes(user_type: 'admin')

      expect(form.save).to be(true)
      expect(user.reload.user_type).to eq('operator')
    end
  end

  describe '.model_name' do
    it 'uses the user param key' do
      expect(described_class.model_name.param_key).to eq('user')
    end
  end
end
