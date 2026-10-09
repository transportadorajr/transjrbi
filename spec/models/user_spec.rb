require 'rails_helper'

RSpec.describe User do
  describe 'validations' do
    it 'requires a name' do
      user = build(:user, name: '')

      expect(user).not_to be_valid
      expect(user.errors[:name]).to include('não pode ficar em branco')
    end

    it 'rejects an unknown user type' do
      user = build(:user, user_type: 'manager')

      expect(user).not_to be_valid
      expect(user.errors[:user_type]).to be_present
    end

    it 'defaults the user type to operator' do
      expect(described_class.new.user_type).to eq('operator')
    end
  end

  describe 'owner per tenant' do
    let!(:tenant) { create(:tenant) }

    before { create(:user, tenant:, user_type: :owner) }

    it 'does not allow a second owner in the same tenant' do
      expect { create(:user, tenant:, user_type: :owner) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows an owner in another tenant' do
      expect { create(:user, user_type: :owner) }.to change(described_class, :count).by(1)
    end
  end

  describe '#user_type_name' do
    it 'translates the user type' do
      expect(build(:user, user_type: :admin).user_type_name).to eq('Administrador')
    end
  end

  describe '.by_name' do
    let!(:maria) { create(:user, name: 'Maria Souza') }

    before { create(:user, name: 'Carlos Lima') }

    it 'matches part of the name ignoring case' do
      expect(described_class.by_name('souza')).to contain_exactly(maria)
    end

    it 'escapes LIKE wildcards' do
      expect(described_class.by_name('%')).to be_empty
    end
  end

  describe '.by_status' do
    let!(:active_user) { create(:user, activated_at: 1.day.ago) }
    let!(:inactive_user) { create(:user, activated_at: nil) }

    it 'returns activated users for active' do
      expect(described_class.by_status('active')).to contain_exactly(active_user)
    end

    it 'returns users without activation for deactivated' do
      expect(described_class.by_status('deactivated')).to contain_exactly(inactive_user)
    end
  end

  describe '#pending_account_confirmation?' do
    it 'is true for an account waiting for confirmation' do
      expect(create(:user, confirmed_at: nil)).to be_pending_account_confirmation
    end

    it 'is false for a confirmed account' do
      expect(create(:user)).not_to be_pending_account_confirmation
    end

    it 'is false when the confirmation link expired' do
      user = create(:user, confirmed_at: nil)

      travel_to(4.days.from_now) do
        expect(user).not_to be_pending_account_confirmation
      end
    end
  end

  describe 'confirmation token' do
    it 'generates a unique hexadecimal token for an account waiting for confirmation' do
      user = create(:user, confirmed_at: nil)
      other_user = create(:user, confirmed_at: nil)

      expect(user.confirmation_token).to match(/\A\h{32}\z/)
      expect(user.confirmation_token).not_to eq(other_user.confirmation_token)
    end

    it 'clears the token after the account is confirmed' do
      user = create(:user, confirmed_at: nil)

      user.confirm

      expect(user.reload.confirmation_token).to be_nil
      expect(user.confirmed_at).to be_present
    end

    it 'keeps the token when the confirmation link expired' do
      user = create(:user, confirmed_at: nil)
      token = user.confirmation_token

      travel_to(4.days.from_now) { user.confirm }

      expect(user.reload.confirmation_token).to eq(token)
      expect(user.confirmed_at).to be_nil
    end
  end

  describe '.statuses' do
    it 'maps the translated labels to the filter keys' do
      expect(described_class.statuses).to eq('Ativo' => :active, 'Inativo' => :deactivated)
    end
  end
end
