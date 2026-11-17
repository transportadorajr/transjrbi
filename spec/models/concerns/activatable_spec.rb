require 'rails_helper'

RSpec.describe Activatable do
  let(:tenant) { create(:tenant) }

  it 'creates a record active by default' do
    city = create(:city, tenant:)

    expect(city.reload).to be_activated
    expect(city.activated_at).to be_present
  end

  it 'creates a record inactive when the activation is cleared' do
    city = create(:city, tenant:, activated_at: nil)

    expect(city.reload).not_to be_activated
    expect(City.not_activated).to eq([city])
  end

  it 'keeps a record active when the clock goes back before its activation' do
    city = create(:city, tenant:)

    travel_to(1.year.ago) do
      expect(City.activated).to eq([city])
      expect(City.by_status('active')).to eq([city])
      expect(City.by_status('deactivated')).to be_empty
    end
  end
end
