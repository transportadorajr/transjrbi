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

  describe '#save with a password defined by the owner' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    it 'creates the user already confirmed with the given password, without the confirmation e-mail', :inline_jobs do
      form = described_class.new(editor: owner, name: 'Ana', email: 'ana@transjrbi.com.br', user_type: 'operator',
                                 password: 'NovaSenha1!', password_confirmation: 'NovaSenha1!')

      expect { form.save }.to change(User, :count).by(1)
        .and not_change { ActionMailer::Base.deliveries.count }

      user = User.last
      expect(user.confirmed_at).to be_present
      expect(user.confirmation_token).to be_nil
      expect(user.valid_password?('NovaSenha1!')).to be(true)
    end

    it 'sends the confirmation e-mail when the owner leaves the password blank', :inline_jobs do
      form = described_class.new(editor: owner, name: 'Ana', email: 'ana@transjrbi.com.br', user_type: 'operator')

      expect { form.save }.to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(User.last.confirmed_at).to be_nil
    end

    it 'rejects a password that does not match its confirmation' do
      form = described_class.new(editor: owner, name: 'Ana', email: 'ana@transjrbi.com.br', user_type: 'operator',
                                 password: 'NovaSenha1!', password_confirmation: 'Outra123!')

      expect { form.save }.not_to change(User, :count)
      expect(form.errors[:password_confirmation]).to include('não é igual a Senha')
    end

    it 'rejects a password that is too short' do
      form = described_class.new(editor: owner, name: 'Ana', email: 'ana@transjrbi.com.br', user_type: 'operator',
                                 password: '123', password_confirmation: '123')

      expect(form).not_to be_valid
      expect(form.errors[:password]).to be_present
    end

    it 'confirms a pending user with the given password' do
      pending_user = create(:user, tenant:, confirmed_at: nil)
      form = described_class.for_user(pending_user, editor: owner)
      form.assign_attributes(password: 'NovaSenha1!', password_confirmation: 'NovaSenha1!')

      expect(form.save).to be(true)

      pending_user.reload
      expect(pending_user.confirmed_at).to be_present
      expect(pending_user.confirmation_token).to be_nil
      expect(pending_user.valid_password?('NovaSenha1!')).to be(true)
    end

    it 'does not change the password of a user that already confirmed the account' do
      confirmed_user = create(:user, tenant:)
      form = described_class.for_user(confirmed_user, editor: owner)
      form.assign_attributes(password: 'NovaSenha1!', password_confirmation: 'NovaSenha1!')

      expect(form.password_settable?).to be(false)
      expect(form.save).to be(true)
      expect(confirmed_user.reload.valid_password?('Senha123!')).to be(true)
    end

    it 'ignores the password when the editor is not the owner' do
      form = described_class.new(editor:, name: 'Ana', email: 'ana@transjrbi.com.br', user_type: 'operator',
                                 password: 'NovaSenha1!', password_confirmation: 'NovaSenha1!')

      expect(form.password_settable?).to be(false)
      expect(form.save).to be(true)

      user = User.last
      expect(user.confirmed_at).to be_nil
      expect(user.valid_password?('NovaSenha1!')).to be(false)
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

  describe 'accesses' do
    let!(:freights) { create(:resource, name: 'Fretes', slug: 'freights', writable: true) }
    let!(:reports) { create(:resource, name: 'Relatórios', slug: 'reports', writable: false) }

    context 'when creating a user' do
      let(:form) do
        described_class.new(
          editor:, name: 'Ana', email: 'ana@transjrbi.com.br', user_type: 'operator',
          access_attributes: {
            '0' => { 'resource_id' => freights.id.to_s, 'reads' => '0', 'creates' => '1' },
            '1' => { 'resource_id' => reports.id.to_s, 'reads' => '1', 'creates' => '1' },
          }
        )
      end

      it 'saves the accesses in the tenant of the user' do
        expect { form.save }.to change(Access, :count).by(2)

        user = User.last
        freights_access = user.accesses.find_by(resource: freights)
        reports_access = user.accesses.find_by(resource: reports)
        expect(freights_access.tenant).to eq(tenant)
        expect(freights_access.reads).to be(true)
        expect(freights_access.creates).to be(true)
        expect(reports_access.reads).to be(true)
        expect(reports_access.creates).to be(false)
      end
    end

    context 'when editing a user with accesses' do
      let!(:user) { create(:user, tenant:) }
      let!(:freights_access) { create(:access, user:, resource: freights, reads: true, creates: true) }

      it 'updates the existing access and removes the unchecked ones' do
        form = described_class.for_user(user, editor:)
        form.assign_attributes(
          access_attributes: {
            '0' => { 'resource_id' => freights.id.to_s, 'reads' => '0', 'creates' => '0' },
            '1' => { 'resource_id' => reports.id.to_s, 'reads' => '1', 'creates' => '0' },
          },
        )

        expect { form.save }.not_to change(Access, :count)

        expect(Access.exists?(freights_access.id)).to be(false)
        expect(user.accesses.sole.resource).to eq(reports)
      end

      it 'does not duplicate accesses when saved twice' do
        attributes = { access_attributes: { '0' => { 'resource_id' => freights.id.to_s, 'reads' => '1', 'creates' => '0' } } }

        2.times do
          form = described_class.for_user(user, editor:)
          form.assign_attributes(attributes)
          form.save
        end

        expect(user.accesses.count).to eq(1)
        expect(freights_access.reload.creates).to be(false)
      end

      it 'keeps the accesses when an operator edits its own account' do
        form = described_class.for_user(user, editor: user)
        form.assign_attributes(
          access_attributes: { '0' => { 'resource_id' => reports.id.to_s, 'reads' => '1', 'creates' => '0' } },
        )

        expect { form.save }.not_to change(Access, :count)
        expect(user.accesses.sole).to eq(freights_access)
      end

      it 'builds the access of each resource from the saved values' do
        form = described_class.for_user(user, editor:)

        expect(form.access_for(freights)).to eq(freights_access)
        expect(form.access_for(reports)).to be_new_record
      end
    end
  end

  describe '.model_name' do
    it 'uses the user param key' do
      expect(described_class.model_name.param_key).to eq('user')
    end
  end

  describe '.enum_options_for_select' do
    it 'translates the user types with the user enum translations' do
      expect(described_class.enum_options_for_select(:user_type)).to eq([%w[Administrador admin], %w[Operador operator]])
    end
  end
end
