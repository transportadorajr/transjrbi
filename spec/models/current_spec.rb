require 'rails_helper'

RSpec.describe Current do
  let!(:admin_user) { create(:admin_user) }

  it 'keeps the admin user only while the attributes are set' do
    described_class.set(admin_user:) do
      expect(described_class.admin_user).to eq(admin_user)
    end

    expect(described_class.admin_user).to be_nil
  end
end
