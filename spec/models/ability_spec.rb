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
      expect(ability).to be_able_to(:deactivate, teammate)
    end

    it 'cannot deactivate its own account' do
      expect(ability).not_to be_able_to(:deactivate, user)
    end

    it 'cannot reach users of another tenant' do
      expect(ability).not_to be_able_to(:read, stranger)
      expect(ability).not_to be_able_to(:update, stranger)
      expect(ability).not_to be_able_to(:deactivate, stranger)
    end

    it 'cannot reach the resources' do
      expect(ability).not_to be_able_to(:read, Resource)
      expect(ability).not_to be_able_to(:create, Resource)
      expect(ability).not_to be_able_to(:update, Resource)
      expect(ability).not_to be_able_to(:destroy, Resource)
    end
  end

  context 'when the user is an admin' do
    let(:user) { create(:user, tenant:, user_type: :admin) }

    it 'manages the users of its own tenant' do
      expect(ability).to be_able_to(:create, User)
      expect(ability).to be_able_to(:update, teammate)
      expect(ability).to be_able_to(:deactivate, teammate)
    end

    it 'cannot deactivate the owner or its own account' do
      expect(ability).not_to be_able_to(:deactivate, create(:user, tenant:, user_type: :owner))
      expect(ability).not_to be_able_to(:deactivate, user)
    end

    it 'cannot reach users of another tenant' do
      expect(ability).not_to be_able_to(:read, stranger)
      expect(ability).not_to be_able_to(:deactivate, stranger)
    end

    it 'cannot reach the resources' do
      expect(ability).not_to be_able_to(:read, Resource)
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

    it 'cannot deactivate any user' do
      expect(ability).not_to be_able_to(:deactivate, teammate)
      expect(ability).not_to be_able_to(:deactivate, user)
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

  context 'when the owner has no accesses' do
    let(:user) { create(:user, tenant:, user_type: :owner) }
    let!(:freights) { create(:resource, slug: 'freights') }

    it 'manages every resource' do
      expect(ability).to be_able_to(:manage, :freights)
    end
  end

  context 'when the admin has no accesses' do
    let(:user) { create(:user, tenant:, user_type: :admin) }
    let!(:freights) { create(:resource, slug: 'freights') }

    it 'cannot reach any resource' do
      expect(ability).not_to be_able_to(:read, :freights)
    end
  end

  context 'when the admin has accesses to resources' do
    let(:user) { create(:user, tenant:, user_type: :admin) }
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
    end

    it 'cannot reach a resource without access' do
      expect(ability).not_to be_able_to(:read, :trips)
    end
  end

  context 'when the ability is restricted to some resources' do
    subject(:ability) { described_class.new(user, resources: Ability::MAINTENANCE_RESOURCES) }

    let(:user) { create(:user, tenant:, user_type: :owner) }

    before do
      create(:resource, slug: 'maintenance_orders')
      create(:resource, slug: 'vehicles')
      create(:resource, slug: 'truck_groups')
    end

    it 'manages the allowed resources' do
      expect(ability).to be_able_to(:update, :maintenance_orders)
      expect(ability).to be_able_to(:read, :vehicles)
    end

    it 'cannot reach the other resources' do
      expect(ability).not_to be_able_to(:read, :truck_groups)
    end
  end

  context 'when an admin has accesses out of the restricted resources' do
    subject(:ability) { described_class.new(user, resources: Ability::MAINTENANCE_RESOURCES) }

    let(:user) { create(:user, tenant:, user_type: :admin) }

    before do
      create(:access, user:, resource: create(:resource, slug: 'suppliers'), reads: true, creates: true)
      create(:access, user:, resource: create(:resource, slug: 'drivers'), reads: true)
    end

    it 'keeps only the accesses to the allowed resources' do
      expect(ability).to be_able_to(:create, :suppliers)
      expect(ability).not_to be_able_to(:read, :drivers)
    end
  end

  context 'without a signed in user' do
    let(:user) { nil }

    it 'cannot read users' do
      expect(ability).not_to be_able_to(:read, User)
    end
  end
end
