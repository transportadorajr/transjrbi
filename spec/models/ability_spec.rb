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

    it 'manages the resources' do
      expect(ability).to be_able_to(:read, Resource)
      expect(ability).to be_able_to(:create, Resource)
      expect(ability).to be_able_to(:update, Resource)
      expect(ability).to be_able_to(:destroy, Resource)
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

    it 'reads the resources without managing them' do
      expect(ability).to be_able_to(:read, Resource)
      expect(ability).not_to be_able_to(:create, Resource)
      expect(ability).not_to be_able_to(:update, Resource)
      expect(ability).not_to be_able_to(:destroy, Resource)
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

    it 'cannot reach the resources' do
      expect(ability).not_to be_able_to(:read, Resource)
      expect(ability).not_to be_able_to(:create, Resource)
      expect(ability).not_to be_able_to(:update, Resource)
      expect(ability).not_to be_able_to(:destroy, Resource)
    end
  end

  context 'when the operator has accesses to resources' do
    let(:user) { create(:user, tenant:, user_type: :operator) }
    let!(:freights) { create(:resource, slug: 'freights') }
    let!(:reports) { create(:resource, slug: 'reports') }
    let!(:trips) { create(:resource, slug: 'trips') }

    before do
      create(:access, user:, resource: freights, reads: true, creates: true)
      create(:access, user:, resource: reports, reads: true, creates: false)
    end

    it 'manages the resource it can edit' do
      expect(ability).to be_able_to(:read, :freights)
      expect(ability).to be_able_to(:create, :freights)
      expect(ability).to be_able_to(:update, :freights)
      expect(ability).to be_able_to(:destroy, :freights)
    end

    it 'only reads the resource it can read' do
      expect(ability).to be_able_to(:read, :reports)
      expect(ability).not_to be_able_to(:create, :reports)
      expect(ability).not_to be_able_to(:update, :reports)
    end

    it 'cannot reach a resource without access' do
      expect(ability).not_to be_able_to(:read, :trips)
    end

    it 'does not use the accesses of another user' do
      expect(described_class.new(create(:user, tenant:))).not_to be_able_to(:read, :freights)
    end
  end

  context 'when an admin or owner has no accesses' do
    let!(:freights) { create(:resource, slug: 'freights') }

    it 'manages every resource' do
      %i[admin owner].each do |user_type|
        ability = described_class.new(create(:user, tenant: create(:tenant), user_type:))

        expect(ability).to be_able_to(:manage, :freights)
      end
    end
  end

  context 'without a signed in user' do
    let(:user) { nil }

    it 'cannot read users' do
      expect(ability).not_to be_able_to(:read, User)
    end
  end
end
