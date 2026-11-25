require 'rails_helper'

RSpec.describe RiskAssessment do
  describe 'validations' do
    it 'requires a known provider and a non negative score' do
      risk_assessment = described_class.new(provider_type: 'unknown', score: -1)

      expect(risk_assessment).not_to be_valid
      expect(risk_assessment.errors.attribute_names).to include(:provider_type, :score)
    end

    it 'accepts a risk assessment without status, score and validity' do
      risk_assessment = build(:risk_assessment, provider_type: 'opentech', status_type: nil, score: nil, valid_until: nil)

      expect(risk_assessment).to be_valid
    end

    it 'rejects a second risk assessment of the same provider for the employee' do
      existing = create(:risk_assessment, provider_type: 'opentech')

      expect(build(:risk_assessment, employee: existing.employee, provider_type: 'opentech')).not_to be_valid
      expect(build(:risk_assessment, employee: existing.employee, provider_type: 'apisul')).to be_valid
    end
  end

  describe 'Apisul status' do
    it 'does not recommend a score below 60 and recommends from 60 up' do
      expect(create(:risk_assessment, score: 59, status_type: 'recommended')).to be_not_recommended
      expect(create(:risk_assessment, score: 60, status_type: 'not_recommended')).to be_recommended
    end

    it 'keeps the status while the Apisul has no score' do
      expect(create(:risk_assessment, score: nil, status_type: 'in_progress')).to be_in_progress
    end

    it 'keeps the status informed by the Opentech' do
      expect(create(:risk_assessment, provider_type: 'opentech', score: 10, status_type: 'recommended')).to be_recommended
    end
  end

  describe 'scopes' do
    let(:tenant) { create(:tenant) }
    let!(:jose) { create(:employee, tenant:, name: 'JOSE SILVA', company_type: 'transjr') }
    let!(:ana) { create(:employee, tenant:, name: 'ANA PAULA', legal_id: '11144477735', company_type: 'mme') }
    let!(:jose_apisul) { create(:risk_assessment, employee: jose, provider_type: 'apisul') }
    let!(:ana_opentech) { create(:risk_assessment, employee: ana, provider_type: 'opentech', status_type: 'not_recommended', score: nil) }

    it 'filters by the name and the company of the employee' do
      expect(described_class.by_name('jose')).to contain_exactly(jose_apisul)
      expect(described_class.by_company_type('mme')).to contain_exactly(ana_opentech)
    end

    it 'filters by the provider and the status' do
      expect(described_class.by_provider_type('apisul')).to contain_exactly(jose_apisul)
      expect(described_class.by_status_type('not_recommended')).to contain_exactly(ana_opentech)
    end
  end

  describe 'validity scopes' do
    let(:today) { Date.new(2026, 11, 25) }
    let!(:expired) { create(:risk_assessment, valid_until: Date.new(2026, 11, 24)) }
    let!(:expiring_today) { create(:risk_assessment, valid_until: today) }
    let!(:expiring_last_day) { create(:risk_assessment, valid_until: Date.new(2026, 12, 25)) }

    before do
      create(:risk_assessment, valid_until: Date.new(2026, 12, 26))
      create(:risk_assessment, valid_until: nil)
    end

    it 'lists the risk assessments valid until before the date' do
      expect(described_class.expired(today)).to contain_exactly(expired)
    end

    it 'lists the risk assessments that expire in the next 30 days' do
      expect(described_class.expiring(today)).to contain_exactly(expiring_today, expiring_last_day)
    end
  end
end
