require 'rails_helper'

RSpec.describe Admin::Session do
  it 'generates a token and starts the activity clock' do
    session = create(:admin_session, last_active_at: nil)

    expect(session.token).to be_present
    expect(session.last_active_at).to be > 1.minute.ago
  end

  context 'with sessions of different ages' do
    let!(:active) { create(:admin_session, last_active_at: 29.minutes.ago) }
    let!(:expired) { create(:admin_session, last_active_at: 31.minutes.ago) }

    it 'expires after 30 minutes without activity' do
      expect(active).not_to be_expired
      expect(expired).to be_expired
      expect(described_class.expired).to eq([expired])
    end

    it 'renews the activity clock' do
      expired.renew

      expect(expired.reload).not_to be_expired
    end
  end

  describe '.authenticate' do
    let!(:active) { create(:admin_session, last_active_at: 10.minutes.ago) }
    let!(:expired) { create(:admin_session, last_active_at: 31.minutes.ago) }

    it 'returns the active session and renews it' do
      expect(described_class.authenticate(active.token)).to eq(active)
      expect(active.reload.last_active_at).to be > 1.minute.ago
    end

    it 'refuses an expired session without renewing it' do
      expect(described_class.authenticate(expired.token)).to be_nil
      expect(expired.reload).to be_expired
    end

    it 'refuses a blank or unknown token' do
      expect(described_class.authenticate(nil)).to be_nil
      expect(described_class.authenticate('desconhecido')).to be_nil
    end
  end
end
