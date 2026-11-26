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
    expect { run_seeds }.to change(Resource, :count).by(46)

    expect(Resource.find_by!(slug: 'users')).to have_attributes(name: 'Usuários', writable: true)
    expect(Resource.find_by!(slug: 'excluded_issuers')).to have_attributes(name: 'Emissores desconsiderados', writable: true)
    expect(Resource.find_by!(slug: 'route_distances')).to have_attributes(name: 'Trechos de km', writable: true)
    expect(Resource.find_by!(slug: 'revenue_projection_notes')).to have_attributes(name: 'Anotações da projeção', writable: true)
    expect(Resource.find_by!(slug: 'customers')).to have_attributes(name: 'Clientes', writable: false)
    expect(Resource.find_by!(slug: 'advance_icms')).to have_attributes(name: 'ICMS antecipado', writable: false)
    expect(Resource.find_by!(slug: 'product_groups')).to have_attributes(name: 'Grupos de produtos', writable: true)
    expect(Resource.find_by!(slug: 'export_plants')).to have_attributes(name: 'Plantas de exportação', writable: true)
    expect(Resource.find_by!(slug: 'export_summary')).to have_attributes(name: 'Resumo da exportação', writable: false)
    expect(Resource.find_by!(slug: 'export_shortcuts')).to have_attributes(name: 'Atalhos da exportação', writable: true)
    expect(Resource.find_by!(slug: 'freight_billing')).to have_attributes(name: 'Faturamento', writable: false)
    expect(Resource.find_by!(slug: 'trips')).to have_attributes(name: 'Viagens', writable: false)
    expect(Resource.find_by!(slug: 'holidays')).to have_attributes(name: 'Feriados', writable: true)
    expect(Resource.find_by!(slug: 'own_fleet')).to have_attributes(name: 'Frota própria', writable: true)
    expect(Resource.find_by!(slug: 'revenue_projection')).to have_attributes(name: 'Projeção de faturamento', writable: false)
    expect(Resource.find_by!(slug: 'revenue_goals')).to have_attributes(name: 'Metas de faturamento', writable: true)
    expect(Resource.find_by!(slug: 'goals')).to have_attributes(name: 'Painel de metas', writable: false)
    expect(Resource.find_by!(slug: 'maintenance')).to have_attributes(name: 'Módulo de manutenção', writable: false)
    expect(Resource.find_by!(slug: 'maintenance_orders')).to have_attributes(name: 'Ordens de serviço', writable: true)
    expect(Resource.find_by!(slug: 'workshop_employees')).to have_attributes(name: 'Funcionários da oficina', writable: true)
    expect(Resource.find_by!(slug: 'suppliers')).to have_attributes(name: 'Fornecedores', writable: true)
    expect(Resource.find_by!(slug: 'maintenance_parts')).to have_attributes(name: 'Peças da manutenção', writable: true)
    expect(Resource.find_by!(slug: 'risk_assessments')).to have_attributes(name: 'Gerenciadoras de risco', writable: true)
    expect(Resource.find_by!(slug: 'life_insurances')).to have_attributes(name: 'Seguro de vida', writable: true)
    expect(Resource.find_by!(slug: 'emergency_contacts')).to have_attributes(name: 'Contatos de emergência', writable: true)
    expect(Resource.find_by!(slug: 'vehicle_availability')).to have_attributes(name: 'Disponibilidade da frota', writable: false)
    expect(Resource.find_by!(slug: 'maintenance_services')).to have_attributes(name: 'Serviços da manutenção', writable: true)
    expect(Resource.find_by!(slug: 'hr')).to have_attributes(name: 'Módulo de RH', writable: false)
    expect(Resource.find_by!(slug: 'hr_pendencies')).to have_attributes(name: 'Pendências do RH', writable: false)
    expect(Resource.find_by!(slug: 'employees')).to have_attributes(name: 'Funcionários', writable: true)
    expect(Resource.find_by!(slug: 'work_schedules')).to have_attributes(name: 'Escala de folgas', writable: true)
    expect(Resource.find_by!(slug: 'job_positions')).to have_attributes(name: 'Cargos', writable: true)
  end

  it 'registers the HR flag turned off' do
    run_seeds

    expect(Flipper.features.map(&:key)).to include('hr')
    expect(Flipper.enabled?(:hr, tenant)).to be(false)
  end

  it 'registers the trips dashboard and maintenance flags turned off' do
    run_seeds

    expect(Flipper.features.map(&:key)).to include('trips_dashboard', 'maintenance')
    expect(Flipper.enabled?(:trips_dashboard, tenant)).to be(false)
    expect(Flipper.enabled?(:maintenance, tenant)).to be(false)
  end

  it 'does not duplicate the access resources when run again' do
    run_seeds

    expect { run_seeds }.not_to change(Resource, :count)
  end

  context 'with a resource already registered' do
    let!(:resource) { create(:resource, slug: 'users', name: 'Usuários do sistema', writable: false) }

    it 'keeps the registered resource unchanged' do
      expect { run_seeds }.to change(Resource, :count).by(45)

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

  it 'registers the employees and job positions of every tenant' do
    allow(Employees::SeedCommand).to receive(:call)

    run_seeds

    expect(Employees::SeedCommand).to have_received(:call).with(tenant)
    expect(Employees::SeedCommand).to have_received(:call).with(other_tenant)
  end

  it 'registers the risk assessments of every tenant' do
    allow(RiskAssessments::SeedCommand).to receive(:call)

    run_seeds

    expect(RiskAssessments::SeedCommand).to have_received(:call).with(tenant)
    expect(RiskAssessments::SeedCommand).to have_received(:call).with(other_tenant)
  end

  it 'registers the life insurances of every tenant' do
    allow(LifeInsurances::SeedCommand).to receive(:call)

    run_seeds

    expect(LifeInsurances::SeedCommand).to have_received(:call).with(tenant)
    expect(LifeInsurances::SeedCommand).to have_received(:call).with(other_tenant)
  end
end
