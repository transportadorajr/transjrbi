require 'rails_helper'

RSpec.describe RoadRoute do
  let!(:origin) { create(:location) }
  let!(:destination) { create(:location) }

  it 'keeps a single route per origin and destination' do
    create(:road_route, origin:, destination:)
    route = build(:road_route, origin:, destination:)

    expect(route).not_to be_valid
    expect(route.errors[:destination_id]).to be_present
  end

  it 'accepts the opposite direction as another route' do
    create(:road_route, origin:, destination:)

    expect(build(:road_route, origin: destination, destination: origin)).to be_valid
  end

  it 'rejects a negative distance' do
    expect(build(:road_route, origin:, destination:, distance_km: -1)).not_to be_valid
  end
end
