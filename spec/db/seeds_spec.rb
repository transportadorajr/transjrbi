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

  it 'creates every access resource' do
    expect { run_seeds }.to change(Resource, :count).by(17)

    expect(Resource.find_by!(slug: 'users')).to have_attributes(name: 'Usuários', writable: true)
    expect(Resource.find_by!(slug: 'excluded_issuers')).to have_attributes(name: 'Emissores desconsiderados', writable: true)
    expect(Resource.find_by!(slug: 'customers')).to have_attributes(name: 'Clientes', writable: false)
  end

  it 'does not duplicate the access resources when run again' do
    run_seeds

    expect { run_seeds }.not_to change(Resource, :count)
  end

  context 'with a resource already registered' do
    let!(:resource) { create(:resource, slug: 'users', name: 'Usuários do sistema', writable: false) }

    it 'keeps the registered resource unchanged' do
      expect { run_seeds }.to change(Resource, :count).by(16)

      expect(resource.reload).to have_attributes(name: 'Usuários do sistema', writable: false)
    end
  end

  it 'backfills the customer groups of every tenant' do
    run_seeds

    expect(CustomerGroups::BackfillCommand).to have_received(:call).with(tenant)
    expect(CustomerGroups::BackfillCommand).to have_received(:call).with(other_tenant)
  end
end
