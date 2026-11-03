require 'rails_helper'

describe 'Error tracking context' do
  before do
    allow(Sentry).to receive(:set_user)
    allow(Sentry).to receive(:set_tags)
    allow(Rails.error).to receive(:set_context).and_call_original
  end

  context 'when a user is signed in' do
    let!(:user) { create(:user) }

    before { login_as(user, scope: :user) }

    scenario 'identifies the user and the tenant on the reported errors' do
      visit root_path

      expect(Sentry).to have_received(:set_user).with(id: user.id)
      expect(Sentry).to have_received(:set_tags).with(tenant_id: user.tenant_id)
      expect(Rails.error).to have_received(:set_context).with(user_id: user.id, tenant_id: user.tenant_id)
    end
  end

  context 'without a session' do
    scenario 'does not identify anyone' do
      visit root_path

      expect(page).to have_current_path(new_user_session_path)
      expect(Sentry).not_to have_received(:set_user)
    end
  end

  context 'when an admin user is signed in', :admin do
    let!(:admin_user) { create(:admin_user) }

    scenario 'identifies the admin user on the reported errors' do
      sign_in_admin(admin_user)

      expect(Sentry).to have_received(:set_user).with(id: admin_user.id, segment: 'admin')
      expect(Rails.error).to have_received(:set_context).with(admin_user_id: admin_user.id)
    end
  end
end
