require 'rails_helper'

RSpec.describe Admin::TenantForm do
  let(:valid_attributes) do
    {
      name: ' Nova Logística  Ltda ',
      trade_name: 'Nova Log',
      legal_id: '11.222.333/0001-44',
      atua_url: '',
      owner_name: ' Carla  Souza ',
      owner_email: ' Carla@NovaLog.com.br ',
      owner_password: 'Senha123!',
      owner_password_confirmation: 'Senha123!',
    }
  end

  describe '#save' do
    context 'when creating a tenant' do
      it 'creates the tenant and a confirmed owner without sending e-mails' do
        form = described_class.new(valid_attributes)

        expect { expect(form.save).to be(true) }
          .to change(Tenant, :count).by(1)
          .and change(User, :count).by(1)
          .and not_change { ActionMailer::Base.deliveries.count }

        tenant = Tenant.last
        expect(tenant.name).to eq('Nova Logística Ltda')
        expect(tenant.trade_name).to eq('Nova Log')
        expect(tenant.legal_id).to eq('11.222.333/0001-44')
        expect(tenant.atua_url).to be_nil

        owner = User.last
        expect(form.owner).to eq(owner)
        expect(owner.tenant).to eq(tenant)
        expect(owner.name).to eq('Carla Souza')
        expect(owner.email).to eq('carla@novalog.com.br')
        expect(owner.user_type).to eq('owner')
        expect(owner).to be_activated
        expect(owner).to be_confirmed
        expect(owner.valid_password?('Senha123!')).to be(true)
      end

      it 'rejects a tenant without the owner fields' do
        form = described_class.new(valid_attributes.merge(owner_name: '', owner_email: '', owner_password: '',
                                                          owner_password_confirmation: ''))

        expect { expect(form.save).to be_falsey }.not_to change(Tenant, :count)
        expect(form.errors[:owner_name]).to eq(['não pode ficar em branco'])
        expect(form.errors[:owner_email]).to eq(['não pode ficar em branco'])
        expect(form.errors[:owner_password]).to eq(['não pode ficar em branco'])
      end

      it 'rejects an invalid owner e-mail' do
        form = described_class.new(valid_attributes.merge(owner_email: 'carla'))

        expect { expect(form.save).to be_falsey }.not_to change(Tenant, :count)
        expect(form.errors[:owner_email]).to eq(['não é válido'])
      end

      it 'rejects a password shorter than the minimum length' do
        form = described_class.new(valid_attributes.merge(owner_password: 'Abc12', owner_password_confirmation: 'Abc12'))

        expect { expect(form.save).to be_falsey }.not_to change(Tenant, :count)
        expect(form.errors[:owner_password]).to be_present
      end

      it 'rejects a password confirmation that does not match' do
        form = described_class.new(valid_attributes.merge(owner_password_confirmation: 'Outra123!'))

        expect { expect(form.save).to be_falsey }.not_to change(Tenant, :count)
        expect(form.errors[:owner_password_confirmation]).to be_present
      end

      context 'when the owner e-mail is already in use' do
        let!(:existing_user) { create(:user, email: 'carla@novalog.com.br') }

        it 'rejects the duplicated e-mail' do
          form = described_class.new(valid_attributes)

          expect { expect(form.save).to be_falsey }.to not_change(Tenant, :count).and not_change(User, :count)
          expect(form.errors[:owner_email]).to eq(['já está em uso'])
        end
      end

      context 'when the legal id is already taken' do
        let!(:existing_tenant) { create(:tenant, legal_id: '11.222.333/0001-44') }

        it 'rejects the duplicated legal id' do
          form = described_class.new(valid_attributes)

          expect { expect(form.save).to be_falsey }.to not_change(Tenant, :count).and not_change(User, :count)
          expect(form.errors[:legal_id]).to be_present
        end
      end
    end

    context 'when editing a tenant' do
      let!(:tenant) { create(:tenant, name: 'Transportadora JR Ltda', trade_name: 'TransJR') }

      it 'updates the company data without requiring the owner fields' do
        form = described_class.for_tenant(tenant)
        form.assign_attributes(trade_name: 'TransJR Logística')

        expect { expect(form.save).to be(true) }.not_to change(User, :count)
        expect(tenant.reload.trade_name).to eq('TransJR Logística')
        expect(tenant.name).to eq('Transportadora JR Ltda')
      end
    end
  end
end
