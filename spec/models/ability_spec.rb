require 'rails_helper'

RSpec.describe Ability do
  subject(:ability) { described_class.new(user) }

  let(:tenant) { create(:tenant) }
  let(:teammate) { create(:user, tenant:) }
  let(:stranger) { create(:user) }

  context 'when the user is an owner' do
    let(:user) { create(:user, tenant:, user_type: :owner) }

    it 'manages the users of its own tenant' do
      expect(ability).to be_able_to(:create, User)
      expect(ability).to be_able_to(:read, teammate)
      expect(ability).to be_able_to(:update, teammate)
    end

    it 'cannot reach users of another tenant' do
      expect(ability).not_to be_able_to(:read, stranger)
      expect(ability).not_to be_able_to(:update, stranger)
    end
  end

  context 'when the user is an admin' do
    let(:user) { create(:user, tenant:, user_type: :admin) }

    it 'manages the users of its own tenant' do
      expect(ability).to be_able_to(:create, User)
      expect(ability).to be_able_to(:update, teammate)
    end

    it 'cannot reach users of another tenant' do
      expect(ability).not_to be_able_to(:read, stranger)
    end
  end

  context 'when the user is an operator' do
    let(:user) { create(:user, tenant:, user_type: :operator) }

    it 'reads and updates only its own account' do
      expect(ability).to be_able_to(:read, user)
      expect(ability).to be_able_to(:update, user)
    end

    it 'cannot create or reach other users' do
      expect(ability).not_to be_able_to(:create, User)
      expect(ability).not_to be_able_to(:read, teammate)
      expect(ability).not_to be_able_to(:update, teammate)
    end
  end

  context 'without a signed in user' do
    let(:user) { nil }

    it 'cannot read users' do
      expect(ability).not_to be_able_to(:read, User)
    end
  end
end
