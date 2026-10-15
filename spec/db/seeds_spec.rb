require 'rails_helper'

RSpec.describe 'db/seeds.rb' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  before do
    allow(EmptyLegs::CalculateAllCommand).to receive(:call).and_return([])
    allow(CustomerGroups::BackfillCommand).to receive(:call).and_return([])
  end

  def run_seeds
    Rails.application.load_seed
  end

  context 'with the TomTom api key' do
    before { allow(Tomtom).to receive(:configured?).and_return(true) }

    it 'calculates the empty legs of every tenant' do
      run_seeds

      expect(EmptyLegs::CalculateAllCommand).to have_received(:call).with(tenant)
      expect(EmptyLegs::CalculateAllCommand).to have_received(:call).with(other_tenant)
    end
  end

  context 'without the TomTom api key' do
    before { allow(Tomtom).to receive(:configured?).and_return(false) }

    it 'does not calculate the empty legs' do
      run_seeds

      expect(EmptyLegs::CalculateAllCommand).not_to have_received(:call)
    end
  end

  it 'backfills the customer groups of every tenant' do
    run_seeds

    expect(CustomerGroups::BackfillCommand).to have_received(:call).with(tenant)
    expect(CustomerGroups::BackfillCommand).to have_received(:call).with(other_tenant)
  end
end
