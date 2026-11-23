require 'rails_helper'

RSpec.describe Employees::SeedCommand do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }

  describe '.call' do
    it 'registers the job positions and the employees of the payroll report' do
      expect { described_class.call(tenant) }
        .to change(JobPosition, :count).by(16).and change(Employee, :count).by(87)

      expect(tenant.employees.group(:company_type).count).to eq('transjr' => 1, 'mme' => 42, 'mm_espinola' => 44)
      expect(tenant.employees.where(gender_type: 'female').order(:name).pluck(:name)).to eq(
        [
          'ANA JULIA FORMIGUEIRI', 'BARBARA VICTORIA CORREIA', 'DANIELLE CRISTINE SAMPAIO VIEI',
          'JAQUELINE APARECIDA BARBOSA', 'LUANA CRISTINA TSCHOPE', 'MARISA LIMA DE OLIVEIRA',
          'SEBASTIANA DA SILVA NASCIMENTO'
        ],
      )
      expect(tenant.employees.find_by!(company_type: 'mme', registration: '00190')).to have_attributes(
        name: 'BENONIN FERNANDO DA SILVA NETO', legal_id: nil, cost_center: 'MOTORISTAS', gender_type: 'male',
        work_schedule_type: 'five_two', driver: nil, job_position: tenant.job_positions.find_by!(name: 'MOTORISTA DE RODOTREM')
      )
      expect(tenant.employees.find_by!(company_type: 'mm_espinola', registration: '00006')).to have_attributes(
        name: 'DENIS MACIEL DOS SANTOS', cost_center: 'OFICINA',
        job_position: tenant.job_positions.find_by!(name: 'ENCARREGADO DE OFICINA')
      )
      expect(tenant.employees).to all(be_activated)
      expect(other_tenant.employees.count).to eq(0)
    end

    it 'can run again without duplicating the records' do
      described_class.call(tenant)

      expect { described_class.call(tenant) }.not_to change { [JobPosition.count, Employee.count] }
    end

    context 'when the employee was already registered' do
      let!(:sidney) do
        create(:employee, tenant:, name: 'SIDNEY ZEN', legal_id: nil, company_type: 'mme', registration: '00205',
                          nickname: 'ZEN', work_schedule_type: 'not_scheduled')
      end
      let!(:fabio) { create(:employee, tenant:, name: 'FABIO CAUZ', legal_id: '52998224725', company_type: 'mm_espinola') }

      before do
        create(:atua_transport_document, tenant:, driver_code: 2426, driver_name: 'FABIO JOSE CAUZ',
                                         driver_document_digits: '52998224725')
      end

      it 'keeps the registered employee by registration or CPF' do
        expect { described_class.call(tenant) }.to change(Employee, :count).by(85)

        expect(sidney.reload).to have_attributes(nickname: 'ZEN', work_schedule_type: 'not_scheduled', job_position: nil)
        expect(fabio.reload).to have_attributes(name: 'FABIO CAUZ', registration: nil)
      end
    end

    context 'when the CT-es carry the driver CPF' do
      before do
        create(:atua_transport_document, tenant:, driver_code: 4361, driver_name: 'Pedro Henrique Lutz',
                                         driver_document_digits: '52998224725')
        create(:atua_transport_document, tenant:, driver_code: 4100, driver_name: 'ALESSANDRO CELESTINO DOS SANTOS',
                                         driver_document_digits: '11144477735')
        create(:atua_transport_document, tenant:, driver_code: 4200, driver_name: 'SIDNEY ZENATTI',
                                         driver_document_digits: '39053344705')
        create(:atua_transport_document, tenant: other_tenant, driver_code: 9000, driver_name: 'SAMIR REINILDES MOLL',
                                         driver_document_digits: '86288366757')
      end

      it 'fills the CPF and the full name of the driver and links the Atua driver' do
        described_class.call(tenant)

        expect(tenant.employees.find_by!(registration: '00108')).to have_attributes(
          name: 'PEDRO HENRIQUE LUTZ', legal_id: '52998224725', driver_code: 4361,
        )
        expect(tenant.employees.find_by!(company_type: 'mme', registration: '00166')).to have_attributes(
          name: 'ALESSANDRO CELESTINO DOS SANTOS', legal_id: '11144477735', driver_code: 4100,
        )
        expect(tenant.employees.find_by!(company_type: 'mme', registration: '00205'))
          .to have_attributes(name: 'SIDNEY ZEN', legal_id: nil, driver: nil)
        expect(tenant.employees.find_by!(company_type: 'mme', registration: '00206'))
          .to have_attributes(legal_id: nil, driver: nil)
      end
    end
  end
end
