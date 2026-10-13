require 'rails_helper'

RSpec.describe Access do
  describe '#abilities' do
    it 'grants every ability when it creates' do
      expect(build(:access, reads: true, creates: true).abilities).to eq(%i[read create update destroy])
    end

    it 'grants only reading when it reads' do
      expect(build(:access, reads: true, creates: false).abilities).to eq(%i[read])
    end

    it 'grants nothing when no level is enabled' do
      expect(build(:access, reads: false, creates: false).abilities).to eq([])
    end
  end

  describe '#resource_symbol' do
    it 'uses the slug of the resource' do
      access = build(:access, resource: build(:resource, slug: 'freights'))

      expect(access.resource_symbol).to eq(:freights)
    end
  end

  describe 'validations' do
    let!(:access) { create(:access) }

    it 'allows only one access per resource for the same user' do
      duplicated = build(:access, user: access.user, resource: access.resource)

      expect(duplicated).not_to be_valid
      expect(duplicated.errors[:resource_id]).to include('já está em uso')
    end

    it 'allows the same resource for another user' do
      expect(build(:access, resource: access.resource)).to be_valid
    end
  end
end
