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
    expect { run_seeds }.to change(Resource, :count).by(27)

    expect(Resource.find_by!(slug: 'users')).to have_attributes(name: 'Usuários', writable: true)
    expect(Resource.find_by!(slug: 'excluded_issuers')).to have_attributes(name: 'Emissores desconsiderados', writable: true)
    expect(Resource.find_by!(slug: 'route_distances')).to have_attributes(name: 'Trechos de km', writable: true)
    expect(Resource.find_by!(slug: 'customers')).to have_attributes(name: 'Clientes', writable: false)
    expect(Resource.find_by!(slug: 'product_groups')).to have_attributes(name: 'Grupos de produtos', writable: true)
    expect(Resource.find_by!(slug: 'freight_billing')).to have_attributes(name: 'Faturamento', writable: false)
    expect(Resource.find_by!(slug: 'trips')).to have_attributes(name: 'Viagens', writable: false)
    expect(Resource.find_by!(slug: 'holidays')).to have_attributes(name: 'Feriados', writable: true)
    expect(Resource.find_by!(slug: 'own_fleet')).to have_attributes(name: 'Frota própria', writable: true)
    expect(Resource.find_by!(slug: 'revenue_projection')).to have_attributes(name: 'Projeção de faturamento', writable: false)
    expect(Resource.find_by!(slug: 'maintenance')).to have_attributes(name: 'Módulo de manutenção', writable: false)
    expect(Resource.find_by!(slug: 'maintenance_orders')).to have_attributes(name: 'Ordens de serviço', writable: true)
    expect(Resource.find_by!(slug: 'workshop_employees')).to have_attributes(name: 'Funcionários da oficina', writable: true)
    expect(Resource.find_by!(slug: 'suppliers')).to have_attributes(name: 'Fornecedores', writable: true)
  end

  it 'registers the trips dashboard and maintenance flags turned off' do
    run_seeds

    expect(Flipper.features.map(&:key)).to include('trips_dashboard', 'maintenance')
    expect(Flipper.enabled?(:trips_dashboard, tenant)).to be(false)
    expect(Flipper.enabled?(:maintenance, tenant)).to be(false)
  end

  it 'registers the revenue projection flag turned off' do
    run_seeds

    expect(Flipper.features.map(&:key)).to include('revenue_projection')
    expect(Flipper.enabled?(:revenue_projection, tenant)).to be(false)
  end

  it 'does not duplicate the access resources when run again' do
    run_seeds

    expect { run_seeds }.not_to change(Resource, :count)
  end

  context 'with a resource already registered' do
    let!(:resource) { create(:resource, slug: 'users', name: 'Usuários do sistema', writable: false) }

    it 'keeps the registered resource unchanged' do
      expect { run_seeds }.to change(Resource, :count).by(26)

      expect(resource.reload).to have_attributes(name: 'Usuários do sistema', writable: false)
    end
  end

  it 'backfills the customer groups of every tenant' do
    run_seeds

    expect(CustomerGroups::BackfillCommand).to have_received(:call).with(tenant)
    expect(CustomerGroups::BackfillCommand).to have_received(:call).with(other_tenant)
  end

  it 'creates the product groups of every tenant' do
    allow(ProductGroups::BackfillCommand).to receive(:call).and_return([])

    run_seeds

    expect(ProductGroups::BackfillCommand).to have_received(:call).with(tenant)
    expect(ProductGroups::BackfillCommand).to have_received(:call).with(other_tenant)
  end

  it 'registers the national holidays of every tenant' do
    allow(Holidays::SeedNationalCommand).to receive(:call).and_return(Holiday.none)

    run_seeds

    expect(Holidays::SeedNationalCommand).to have_received(:call).with(tenant)
    expect(Holidays::SeedNationalCommand).to have_received(:call).with(other_tenant)
  end
end
